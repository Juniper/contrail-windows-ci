function Get-ContrailVirtualRouterUuidByName {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Name)

    $ExpectedFqName = @("default-global-system-config", $Name)

    return $API.FQNameToUuid('virtual-router', $ExpectedFqName)
}

function New-ContrailVirtualRouter {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Name,
           [Parameter(Mandatory = $true)] [string] $Ip)

    $Request = @{
        "virtual-router" = @{
            parent_type               = "global-system-config"
            fq_name                   = @("default-global-system-config", $Name)
            virtual_router_ip_address = $Ip
        }
    }

    $Response = $API.Post('virtual-router', $null, $Request)

    return $Response.'virtual-router'.'uuid'
}

function Remove-ContrailVirtualRouter {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Uuid)

    $API.Delete('virtual-router', $Uuid, $null)
}

function Add-OrReplaceVirtualRouter {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $RouterName,
           [Parameter(Mandatory = $true)] [string] $RouterIp)
    try {
        return New-ContrailVirtualRouter `
            -API $API `
            -Name $RouterName `
            -Ip $RouterIp
    } catch {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
            throw
        }

        $RouterUuid = Get-ContrailVirtualRouterUuidByName `
            -API $API `
            -Name $RouterName

        Remove-ContrailVirtualRouter `
            -API $API `
            -Uuid $RouterUuid

        return New-ContrailVirtualRouter `
            -API $API `
            -Name $RouterName `
            -Ip $RouterIp
    }
}
