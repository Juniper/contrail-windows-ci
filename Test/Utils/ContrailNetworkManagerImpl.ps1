class ContrailNetworkManager {
    [Int] $CONVERT_TO_JSON_MAX_DEPTH = 100;

    [String] $AuthToken;
    [String] $ContrailUrl;

    ContrailNetworkManager([ControllerConfig] $ControllerConfig, [OpenStackConfig] $OpenStackConfig) {

        $this.ContrailUrl = $ControllerConfig.RestApiUrl()

        if($ControllerConfig.AuthMethod -eq "keystone") {
            if(!$OpenStackConfig) {
                throw "AuthMethod is keystone, but no OpenStack config provided."
            }

            $this.AuthToken = $this.GetAccessTokenFromKeystone($OpenStackConfig)
        }
        elseif ($ControllerConfig.AuthMethod -eq "noauth") {
            $this.AuthToken = $null
        }
        else {
            throw "Unknown authentification method: $($ControllerConfig.AuthMethod). Supported: keystone, noauth."
        }
    }

    hidden [String] GetAccessTokenFromKeystone([OpenStackConfig] $OpenStackConfig) {
        $Request = @{
            auth = @{
                tenantName          = $OpenStackConfig.Project
                passwordCredentials = @{
                    username = $OpenStackConfig.Username
                    password = $OpenStackConfig.Password
                }
            }
        }
        $AuthUrl = $OpenStackConfig.AuthUrl() + "/tokens"
        $Response = Invoke-RestMethod -Uri $AuthUrl -Method Post -ContentType "application/json" `
            -Body (ConvertTo-Json -Depth $this.CONVERT_TO_JSON_MAX_DEPTH $Request)
        return $Response.access.token.id
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

        $RequestUrl = $this.GetResourceUrl($Resource, $Uuid)

        # We need to escape '<>' in 'direction' field because reasons
        # http://www.azurefieldnotes.com/2017/05/02/replacefix-unicode-characters-created-by-convertto-json-in-powershell-for-arm-templates/
        $Body = (ConvertTo-Json -Depth $this.CONVERT_TO_JSON_MAX_DEPTH $Request |
                    ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) })
        $Headers = @{}
        if($this.AuthToken) {
            $Headers = @{"X-Auth-Token" = $this.AuthToken}
        }

        $HeadersString = $Headers.GetEnumerator()  | ForEach-Object { "$($_.Name): $($_.Value)" }
        Write-Log "[Contrail][$Method]=>[$RequestUrl]"
        Write-Log -NoTimestamp -NoTag "Headers:`n$HeadersString;`nBody:`n$Body"

        $Response = Invoke-RestMethod -Uri $RequestUrl -Headers $Headers `
            -Method $Method -ContentType "application/json" `
            -Body $Body
        Write-Log "[Contrail]<= "
        Write-Log -NoTimestamp -NoTag "$Response"
        return $Response
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

    [Void] Delete([String] $Resource, [String] $Uuid, $Request) {
        $this.SendRequest("Delete", $Resource, $Uuid, $Request)
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
