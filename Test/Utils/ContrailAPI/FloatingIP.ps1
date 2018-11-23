function New-ContrailFloatingIp {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $PoolUuid,
           [Parameter(Mandatory = $true)] [string] $Name,
           [Parameter(Mandatory = $true)] [string] $Address)

    $Pool = $API.Get('floating-ip-pool', $PoolUuid, $null)
    $PoolFqName = $Pool."floating-ip-pool".fq_name
    $FipFqName = $PoolFqName + $Name

    $Request = @{
        "floating-ip" = @{
            "floating_ip_address" = $Address
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
           [Parameter(Mandatory = $true)] [string] $Uuid)

    $API.Delete('floating-ip', $Uuid, $null)
}

function Set-ContrailFloatingIpPorts {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $IpUuid,
           [Parameter(Mandatory = $true)] [string[]] $PortFqNames)

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
