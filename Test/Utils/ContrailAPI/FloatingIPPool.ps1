. $PSScriptRoot\Constants.ps1

function Add-ContrailFloatingIpPool {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
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

    $Response = $API.Post('floating-ip-pool', $null, $Request)

    return $Response.'floating-ip-pool'.'uuid'
}

function Remove-ContrailFloatingIpPool {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $PoolUuid)

    $API.Delete('floating-ip-pool', $PoolUuid, $null)
}
