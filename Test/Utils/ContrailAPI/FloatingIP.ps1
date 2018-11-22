. $PSScriptRoot\Constants.ps1

function Add-ContrailFloatingIp {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $PoolUuid,
           [Parameter(Mandatory = $true)] [string] $IPName,
           [Parameter(Mandatory = $true)] [string] $IPAddress)


    $Pool = $API.Get('floating-ip-pool', $PoolUuid, $null)

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
    $Response = $API.Post('floating-ip', $null, $Request)

    return $Response.'floating-ip'.'uuid'
}

function Remove-ContrailFloatingIp {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $IpUuid)

    $API.Delete('floating-ip', $IpUuid, $null)
}

function Set-ContrailFloatingIpPorts {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $IpUuid,
           [Parameter(Mandatory = $true)] [string[]] $PortFqNames,
           [Parameter(Mandatory = $false)] [string] $TenantName)

    $Fip = $API.Get('floating-ip', $IpUuid, $null)

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

    $API.Put('floating-ip', $IpUuid, $RequestBody)
}
