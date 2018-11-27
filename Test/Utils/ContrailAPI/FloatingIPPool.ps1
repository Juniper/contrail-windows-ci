function New-ContrailFloatingIpPool {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Name,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $NetworkName)

    $Request = @{
        "floating-ip-pool" = @{
            "fq_name" = @("default-domain", $TenantName, $NetworkName, $Name)
            "parent_type" = "virtual-network"
            "uuid" = $null
        }
    }

    $Response = $API.Post('floating-ip-pool', $null, $Request)

    return $Response.'floating-ip-pool'.'uuid'
}

function Remove-ContrailFloatingIpPool {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Uuid)

    $API.Delete('floating-ip-pool', $Uuid, $null)
}
