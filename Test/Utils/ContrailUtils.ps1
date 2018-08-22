$CONVERT_TO_JSON_MAX_DEPTH = 100

function Get-AccessTokenFromKeystone {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingUserNameAndPassWordParams",
        "", Justification="We don't care that it's plaintext, it's just test env.")]
    Param ([Parameter(Mandatory = $true)] [string] $AuthUrl,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Username,
           [Parameter(Mandatory = $true)] [string] $Password)

    $Request = @{
        auth = @{
            tenantName          = $TenantName
            passwordCredentials = @{
                username = $Username
                password = $Password
            }
        }
    }

    $AuthUrl += "/tokens"
    $Response = Invoke-RestMethod -Uri $AuthUrl -Method Post -ContentType "application/json" `
        -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)
    return $Response.access.token.id
}

function Add-ContrailProject {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $ProjectName)

    $Request = @{
        "project" = @{
            fq_name = @("default-domain", $ProjectName)
        }
    }

    $RequestUrl = $ContrailUrl + "/projects"
    $Response = Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post -ContentType "application/json" -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)

    return $Response.'project'.'uuid'
}

class SubnetConfiguration {
    [string] $IpPrefix;
    [int] $IpPrefixLen;
    [string] $DefaultGateway;
    [string] $AllocationPoolsStart;
    [string] $AllocationPoolsEnd;

    SubnetConfiguration([string] $IpPrefix, [int] $IpPrefixLen,
        [string] $DefaultGateway, [string] $AllocationPoolsStart,
        [string] $AllocationPoolsEnd) {
        $this.IpPrefix = $IpPrefix
        $this.IpPrefixLen = $IpPrefixLen
        $this.DefaultGateway = $DefaultGateway;
        $this.AllocationPoolsStart = $AllocationPoolsStart;
        $this.AllocationPoolsEnd = $AllocationPoolsEnd;
    }
}

function Add-ContrailVirtualNetwork {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
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

    $RequestUrl = $ContrailUrl + "/virtual-networks"
    $Response = Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post -ContentType "application/json" -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)

    return $Response.'virtual-network'.'uuid'
}

function Remove-ContrailVirtualNetwork {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $NetworkUuid,
           [bool] $Force = $false)

    $NetworkUrl = $ContrailUrl + "/virtual-network/" + $NetworkUuid
    $Network = Invoke-RestMethod -Method Get -Uri $NetworkUrl -Headers @{"X-Auth-Token" = $AuthToken}

    if ($Force) {
        # TODO remove this outer if, this is only a quick workaround,
        # because sometimes the fields below are empty,
        # and that's a failure in strict mode (I guess).
        $VirtualMachines = $Network.'virtual-network'.virtual_machine_interface_back_refs
        $IpInstances = $Network.'virtual-network'.instance_ip_back_refs

        if ($VirtualMachines -or $IpInstances) {
            if (!$Force) {
                Write-Error "Couldn't remove network. Resources are still referred. Use force mode"
                return
            }

            # First we have to remove resources referred by network instance in correct order:
            #   - Instance IPs
            #   - Virtual machines
            ForEach ($IpInstance in $IpInstances) {
                Invoke-RestMethod -Uri $IpInstance.href -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete | Out-Null
            }

            ForEach ($VirtualMachine in $VirtualMachines) {
                Invoke-RestMethod -Uri $VirtualMachine.href -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete | Out-Null
            }
        }
    }

    # We can now remove the network
    Invoke-RestMethod -Uri $NetworkUrl -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete | Out-Null
}

function Get-ContrailVirtualNetworkPorts {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $NetworkUuid)

    $VirtualNetworkUrl = $ContrailUrl + "/virtual-network/" + $NetworkUuid
    $VirtualNetwork = Invoke-RestMethod -Uri $VirtualNetworkUrl -Headers @{"X-Auth-Token" = $AuthToken}
    $Interfaces = $VirtualNetwork.'virtual-network'.virtual_machine_interface_back_refs

    $Result = @()
    foreach ($Interface in $Interfaces) {
        $FqName = $Interface.to -Join ":"
        $Result = $Result + $FqName
    }

    return $Result
}

function Add-ContrailVirtualRouter {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $RouterName,
           [Parameter(Mandatory = $true)] [string] $RouterIp)

    $Request = @{
        "virtual-router" = @{
            parent_type               = "global-system-config"
            fq_name                   = @("default-global-system-config", $RouterName)
            virtual_router_ip_address = $RouterIp
        }
    }

    $RequestUrl = $ContrailUrl + "/virtual-routers"
    $Response = Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post -ContentType "application/json" -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)

    return $Response.'virtual-router'.'uuid'
}

function Remove-ContrailVirtualRouter {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $RouterUuid)

    $RequestUrl = $ContrailUrl + "/virtual-router/" + $RouterUuid
    Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete | Out-Null
}

function Add-ContrailFloatingIpPool {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $NetworkName,
           [Parameter(Mandatory = $true)] [string] $PoolName)

    $Request = @{
        "floating-ip-pool" = @{
            "fq_name" = @("default-domain", $TenantName, $NetworkName, $PoolName)
            "parent_type" = "virtual-network"
            "uuid" = $null
        }
    }

    $RequestUrl = $ContrailUrl + "/floating-ip-pools"
    $Response = Invoke-RestMethod `
        -Uri $RequestUrl `
        -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post `
        -ContentType "application/json" `
        -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)

    return $Response.'floating-ip-pool'.'uuid'
}

function Remove-ContrailFloatingIpPool {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $PoolUuid)

    $RequestUrl = $ContrailUrl + "/floating-ip-pool/" + $PoolUuid
    Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete | Out-Null
}

function Add-ContrailFloatingIp {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $PoolUuid,
           [Parameter(Mandatory = $true)] [string] $IPName,
           [Parameter(Mandatory = $true)] [string] $IPAddress)

    $PoolUrl = $ContrailUrl + "/floating-ip-pool/" + $PoolUuid
    $Pool = Invoke-RestMethod -Uri $PoolUrl -Headers @{"X-Auth-Token" = $AuthToken}

    $PoolFqName = $Pool."floating-ip-pool".fq_name
    $FipFqName = $PoolFqName + $IPName

    $Request = @{
        "floating-ip" = @{
            "floating_ip_address" = $IPAddress
            "fq_name" = $FipFqName
            "parent_type" = "floating-ip-pool"
            "uuid" = $null
        }
    }
    $RequestUrl = $ContrailUrl + "/floating-ips"
    $Response = Invoke-RestMethod `
        -Uri $RequestUrl `
        -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post `
        -ContentType "application/json" `
        -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)
    return $Response.'floating-ip'.'uuid'
}

function Assign-ContrailFloatingIpToPorts {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $IpUuid,
           [Parameter(Mandatory = $true)] [string[]] $PortFqNames,
           [Parameter(Mandatory = $false)] [string[]] $TenantName)

    $FipUrl = $ContrailUrl + "/floating-ip/" + $IpUuid
    $Fip = Invoke-RestMethod -Uri $FipUrl -Headers @{"X-Auth-Token" = $AuthToken}

    $InterfaceRefs = @()
    foreach ($PortFqName in $PortFqNames) {
        $Ref = @{
            "to" = $PortFqName -Split ":"
        }
        $InterfaceRefs = $InterfaceRefs + $Ref
    }

    $RequestBody = @{
        "floating-ip" = @{
            "floating_ip_address" = $Fip.'floating-ip'.floating_ip_address
            "fq_name" = $Fip.'floating-ip'.fq_name
            "parent_type" = $Fip.'floating-ip'.parent_type
            "uuid" = $Fip.'floating-ip'.uuid
            "virtual_machine_interface_refs" = $InterfaceRefs
        }
    }
    Invoke-RestMethod `
        -Uri $FipUrl `
        -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Put `
        -ContentType "application/json" `
        -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $RequestBody)
}

function Remove-ContrailFloatingIp {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $IpUuid)

    $RequestUrl = $ContrailUrl + "/floating-ip/" + $IpUuid
    Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete | Out-Null
}
