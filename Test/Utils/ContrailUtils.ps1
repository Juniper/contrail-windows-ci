. $PSScriptRoot\ContrailAPI\Constants.ps1

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
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $ProjectName)

    $Request = @{
        "project" = @{
            fq_name = @("default-domain", $ProjectName)
        }
    }

    $Response = $API.Post('project', $null, $Request)

    return $Response.'project'.'uuid'
}

function Ensure-ContrailProject {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $ProjectName)

    try {
        Add-ContrailProject `
            -API $API `
            -ProjectName $ProjectName
    }
    catch {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
            throw
        }
    }
}
