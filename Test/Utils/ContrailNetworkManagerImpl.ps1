class ContrailNetworkManager {
    [Int] $CONVERT_TO_JSON_MAX_DEPTH = 100;

    [String] $AuthToken;
    [String] $ContrailUrl;
    [String] $DefaultTenantName;

    # We cannot add a type to the parameters,
    # because the class is parsed before the files are sourced.
    ContrailNetworkManager($OpenStackConfig, $ControllerConfig) {

        $this.ContrailUrl = $ControllerConfig.RestApiUrl()
        $this.DefaultTenantName = $ControllerConfig.DefaultProject

        $this.AuthToken = Get-AccessTokenFromKeystone `
            -AuthUrl $OpenStackConfig.AuthUrl() `
            -Username $OpenStackConfig.Username `
            -Password $OpenStackConfig.Password `
            -Tenant $OpenStackConfig.Project
    }

    [PSObject] GetResourceUrl([String] $Resource, [String] $Uuid) {
        $RequestUrl = $this.ContrailUrl + "/" + $Resource

        if(-not $Uuid) {
            $RequestUrl += "s"
        } else {
            $RequestUrl += ("/" + $Uuid)
        }

        return $RequestUrl
    }

    hidden [PSObject] SendRequest([String] $Method, [String] $Resource,
                                  [String] $Uuid, $Request) {
        $RequestUrl = $this.GetResourceUrl($Resource, $Uuid.Trim())
        # We need to escape '<>' in 'direction' field because reasons
        # http://www.azurefieldnotes.com/2017/05/02/replacefix-unicode-characters-created-by-convertto-json-in-powershell-for-arm-templates/
        $Body = (ConvertTo-Json -Depth $this.CONVERT_TO_JSON_MAX_DEPTH $Request |
                    ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) })
        Write-Log "[Contrail][$Method]=>[$RequestUrl] $Body"
        return Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $this.AuthToken} `
            -Method $Method -ContentType "application/json" `
            -Body $Body
    }

    [PSObject] Get([String] $Resource, [String] $Uuid, $Request) {
        return $this.SendRequest("Get", $Resource, $Uuid, $Request)
    }

    [PSObject] Post([String] $Resource, [String] $Uuid, $Request) {
        return $this.SendRequest("Post", $Resource, $Uuid, $Request)
    }

    [PSObject] Put([String] $Resource, [String] $Uuid, $Request) {
        return $this.SendRequest("Put", $Resource, $Uuid, $Request)
    }

    [PSObject] Delete([String] $Resource, [String] $Uuid, $Request) {
        return $this.SendRequest("Delete", $Resource, $Uuid, $Request)
    }

    [String] FQNameToUuid ([string] $Resource, [string[]] $FQName) {
        $Request = @{
            type     = $Resource
            fq_name  = $FQName
        }

        $RequestUrl = $this.ContrailUrl + "/fqname-to-id"
        $Response = Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $this.AuthToken} `
            -Method "Post" -ContentType "application/json" -Body (ConvertTo-Json -Depth $this.CONVERT_TO_JSON_MAX_DEPTH $Request)
        return $Response.'uuid'
    }
}

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
        -Body (ConvertTo-Json -Depth 100 $Request)
    return $Response.access.token.id
}
