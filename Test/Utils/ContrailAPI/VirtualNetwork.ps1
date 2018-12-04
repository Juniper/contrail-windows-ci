. $PSScriptRoot\..\DockerNetwork\DockerNetwork.ps1

function Get-ContrailVirtualNetworkUuidByName {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Name)

    $ExpectedFqName = @("default-domain", $TenantName, $Name)

    return $API.FQNameToUuid('virtual-network', $ExpectedFqName)
}

function New-ContrailVirtualNetwork {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Name,
           [SubnetConfiguration] $Subnet = [SubnetConfiguration]::new("10.0.0.0", 24, "10.0.0.1", "10.0.0.100", "10.0.0.200"))

    $IpamSubnet = @{
        subnet           = @{
            ip_prefix     = $Subnet.IpPrefix
            ip_prefix_len = $Subnet.IpPrefixLen
        }
        addr_from_start  = $true
        enable_dhcp      = $true
        default_gateway  = $Subnet.DefaultGateway
        allocation_pools = @(@{
                start = $Subnet.AllocationPoolsStart
                end   = $Subnet.AllocationPoolsEnd
            })
    }

    $NetworkImap = @{
        attr = @{
            ipam_subnets = @($IpamSubnet)
        }
        to   = @("default-domain", "default-project", "default-network-ipam")
    }

    $Request = @{
        "virtual-network" = @{
            parent_type       = "project"
            fq_name           = @("default-domain", $TenantName, $Name)
            network_ipam_refs = @($NetworkImap)
        }
    }

    $Response = $API.Post('virtual-network', $null, $Request)

    return $Response.'virtual-network'.'uuid'
}

function Remove-ContrailVirtualNetwork {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Uuid,
           [bool] $Force = $false)

    $Network = $API.Get('virtual-network', $Uuid, $null)

    $Props = $Network.'virtual-network'.PSobject.Properties.Name

    $VirtualMachines = $null
    $IpInstances = $null

    if($Props -contains 'virtual_machine_interface_back_refs') {
        $VirtualMachines = $Network.'virtual-network'.virtual_machine_interface_back_refs
    }

    if($Props -contains 'instance_ip_back_refs') {
        $IpInstances = $Network.'virtual-network'.instance_ip_back_refs
    }

    if ($VirtualMachines -or $IpInstances) {
        if (!$Force) {
            Write-Error "Couldn't remove network. Resources are still referred. Use force mode"
            return
        }

        # First we have to remove resources referred by network instance in correct order:
        #   - Instance IPs
        #   - Virtual machines
        if($IpInstances) {
            ForEach ($IpInstance in $IpInstances) {
                $API.Delete('instance-ip', $IpInstance.'uuid', $null)
            }
        }

        if($VirtualMachines) {
            ForEach ($VirtualMachine in $VirtualMachines) {
                $API.Delete('virtual-machine-interface', $VirtualMachine.'uuid', $null)
            }
        }
    }

    $API.Delete('virtual-network', $Uuid, $null)
}

# TODO support multiple subnets per network
# TODO return a class (perhaps use the class from MultiTenancy test?)
function Add-OrReplaceNetwork {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Name,
           [Parameter(Mandatory = $true)] [SubnetConfiguration] $SubnetConfig)

    try {
        return New-ContrailVirtualNetwork `
            -API $API `
            -TenantName $TenantName `
            -Name $Name `
            -Subnet $SubnetConfig
    } catch {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
            throw
        }

        $NetworkUuid = Get-ContrailVirtualNetworkUuidByName `
            -API $API `
            -TenantName $TenantName `
            -Name $Name

        Remove-ContrailVirtualNetwork `
            -API $API `
            -Uuid $NetworkUuid

        return New-ContrailVirtualNetwork `
            -API $API `
            -TenantName $TenantName `
            -Name $Name `
            -Subnet $SubnetConfig
    }
}

function Get-ContrailVirtualNetworkPorts {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $NetworkUuid)

    $VirtualNetwork = $API.Get('virtual-network', $NetworkUuid, $null)

    $Interfaces = $VirtualNetwork.'virtual-network'.virtual_machine_interface_back_refs

    $Result = @()
    foreach ($Interface in $Interfaces) {
        $FqName = $Interface.to
        $Result += ,$FqName
    }

    return ,$Result
}

function Add-ContrailPolicyToNetwork {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $PolicyUuid,
           [Parameter(Mandatory = $true)] [string] $NetworkUuid)
    $PolicyRef = @{
        "uuid" = $PolicyUuid
        "attr" = @{
            "timer" = $null
            "sequence" = @{
                "major" = 0
                "minor" = 0
            }
        }
    }
    $BodyObject = @{
        "virtual-network" = @{
            "uuid" = $NetworkUuid
            "network_policy_refs" = @( $PolicyRef )
        }
    }

    $API.Put('virtual-network', $NetworkUuid, $BodyObject) | Out-Null
}
