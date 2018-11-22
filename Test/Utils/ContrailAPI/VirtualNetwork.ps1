. $PSScriptRoot\..\DockerNetwork\DockerNetwork.ps1
. $PSScriptRoot\Constants.ps1

function Get-ContrailVirtualNetworkUuidByName {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $NetworkName)

    $ExpectedFqName = @("default-domain", $TenantName, $NetworkName)

    return $API.FQNameToUuid('virtual-network', $ExpectedFqName)
}

function Add-ContrailVirtualNetwork {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $NetworkName,
           [SubnetConfiguration] $SubnetConfig = [SubnetConfiguration]::new("10.0.0.0", 24, "10.0.0.1", "10.0.0.100", "10.0.0.200"))

    $Subnet = @{
        subnet           = @{
            ip_prefix     = $SubnetConfig.IpPrefix
            ip_prefix_len = $SubnetConfig.IpPrefixLen
        }
        addr_from_start  = $true
        enable_dhcp      = $true
        default_gateway  = $SubnetConfig.DefaultGateway
        allocation_pools = @(@{
                start = $SubnetConfig.AllocationPoolsStart
                end   = $SubnetConfig.AllocationPoolsEnd
            })
    }

    $NetworkImap = @{
        attr = @{
            ipam_subnets = @($Subnet)
        }
        to   = @("default-domain", "default-project", "default-network-ipam")
    }

    $Request = @{
        "virtual-network" = @{
            parent_type       = "project"
            fq_name           = @("default-domain", $TenantName, $NetworkName)
            network_ipam_refs = @($NetworkImap)
        }
    }

    $Response = $API.Post('virtual-network', $null, $Request)

    return $Response.'virtual-network'.'uuid'
}

function Remove-ContrailVirtualNetwork {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $NetworkUuid,
           [bool] $Force = $false)

    $Network = $API.Get('virtual-network', $NetworkUuid, $null)

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

    $API.Delete('virtual-network', $NetworkUuid, $null)
}

# TODO support multiple subnets per network
# TODO return a class (perhaps use the class from MultiTenancy test?)
function Add-OrReplaceNetwork {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Name,
           [Parameter(Mandatory = $true)] [SubnetConfiguration] $SubnetConfig)

    try {
        return Add-ContrailVirtualNetwork `
            -API $API `
            -TenantName $TenantName `
            -NetworkName $Name `
            -SubnetConfig $SubnetConfig
    } catch {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
            throw
        }

        $NetworkUuid = Get-ContrailVirtualNetworkUuidByName `
            -API $API `
            -TenantName $TenantName `
            -NetworkName $Name

        Remove-ContrailVirtualNetwork `
            -API $API `
            -NetworkUuid $NetworkUuid

        return Add-ContrailVirtualNetwork `
            -API $API `
            -TenantName $TenantName `
            -NetworkName $Name `
            -SubnetConfig $SubnetConfig
    }
}

function Get-ContrailVirtualNetworkPorts {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $NetworkUuid)

    $VirtualNetwork = $API.Get('virtual-network', $NetworkUuid, $null)

    $Interfaces = $VirtualNetwork.'virtual-network'.virtual_machine_interface_back_refs

    $Result = @()
    foreach ($Interface in $Interfaces) {
        $FqName = $Interface.to -Join ":"
        $Result = $Result + $FqName
    }

    return $Result
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

    $API.Put('virtual-network', $NetworkUuid, $BodyObject)
}
