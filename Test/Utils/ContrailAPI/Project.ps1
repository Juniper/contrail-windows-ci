function New-ContrailProject {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Name)

    $Request = @{
        "project" = @{
            fq_name = @("default-domain", $Name)
        }
    }

    $Response = $API.Post('project', $null, $Request)

    return $Response.'project'.'uuid'
}

function Add-OrReplaceContrailProject {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Name)

    try {
        New-ContrailProject `
            -API $API `
            -Name $Name | Out-Null
    }
    catch {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
            throw
        }
    }
}
