. $PSScriptRoot\Constants.ps1

function Get-ContrailVirtualRouterUuidByName {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $RouterName)

    $ExpectedFqName = @("default-global-system-config", $RouterName)

    return $API.FQNameToUuid('virtual-router', $ExpectedFqName)
}

function Add-ContrailVirtualRouter {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $RouterName,
           [Parameter(Mandatory = $true)] [string] $RouterIp)

    $Request = @{
        "virtual-router" = @{
            parent_type               = "global-system-config"
            fq_name                   = @("default-global-system-config", $RouterName)
            virtual_router_ip_address = $RouterIp
        }
    }

    $Response = $API.Post('virtual-router', $null, $Request)

    return $Response.'virtual-router'.'uuid'
}

function Remove-ContrailVirtualRouter {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $RouterUuid)

    $API.Delete('virtual-router', $RouterUuid, $null)
}

function Add-OrReplaceVirtualRouter {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $RouterName,
           [Parameter(Mandatory = $true)] [string] $RouterIp)
    try {
        return Add-ContrailVirtualRouter `
            -API $API `
            -RouterName $RouterName `
            -RouterIp $RouterIp
    } catch {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
            throw
        }

        $RouterUuid = Get-ContrailVirtualRouterUuidByName `
            -API $API `
            -RouterName $RouterName

        Remove-ContrailVirtualRouter `
            -API $API `
            -RouterUuid $RouterUuid

        return Add-ContrailVirtualRouter `
            -API $API `
            -RouterName $RouterName `
            -RouterIp $RouterIp
    }
}
