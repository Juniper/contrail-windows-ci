class ContrailRestApi {
    [Int] $CONVERT_TO_JSON_MAX_DEPTH = 100;

    [String] $AuthToken;
    [String] $ContrailUrl;
    [String] $DefaultTenantName;

    ContrailRestApi([OpenStackConfig] $OpenStackConfig, [ControllerConfig] $ControllerConfig) {

        $this.ContrailUrl = $ControllerConfig.RestApiUrl()
        $this.DefaultTenantName = $ControllerConfig.DefaultProject

        if ($ControllerConfig.AuthMethod -eq 'keystone') {
            if (!$OpenStackConfig) {
                throw 'AuthMethod is keystone, but no OpenStack config provided.'
            }

            $this.AuthToken = $this.GetAccessTokenFromKeystone($OpenStackConfig)
        }
        elseif ($ControllerConfig.AuthMethod -eq 'noauth') {
            $this.AuthToken = $null
        }
        else {
            throw "Unknown authentification method: $($ControllerConfig.AuthMethod). Supported: keystone, noauth."
        }
    }

    # The token get by this method can expire.
    # In that case all request done using it will fail.
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
        $AuthUrl = $OpenStackConfig.AuthUrl() + '/tokens'
        $Response = Invoke-RestMethod -Uri $AuthUrl -Method Post -ContentType 'application/json' `
            -Body (ConvertTo-Json -Depth $this.CONVERT_TO_JSON_MAX_DEPTH $Request)
        return $Response.access.token.id
    }

    hidden [String] GetResourceUrl([String] $Resource, [String] $Uuid) {
        $RequestUrl = $this.ContrailUrl + '/' + $Resource

        if (-not $Uuid) {
            $RequestUrl += 's'
        }
        else {
            $RequestUrl += ('/' + $Uuid)
        }

        return $RequestUrl
    }

    hidden [PSObject] SendRequest([String] $Method, [String] $RequestUrl,
        [Hashtable] $Request) {

        # We need to escape '<>' in 'direction' field because reasons
        # http://www.azurefieldnotes.com/2017/05/02/replacefix-unicode-characters-created-by-convertto-json-in-powershell-for-arm-templates/
        $Body = (ConvertTo-Json -Depth $this.CONVERT_TO_JSON_MAX_DEPTH $Request |
                ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) })
        $Headers = $null
        $HeadersString = $null
        if ($this.AuthToken) {
            $Headers = @{'X-Auth-Token' = $this.AuthToken}
        }

        if ($Headers) {
            $HeadersString = $Headers.GetEnumerator()  | ForEach-Object { "$($_.Name): $($_.Value)" }
        }
        Write-Log "[Contrail][$Method]=>[$RequestUrl]"
        Write-Log -NoTimestamp -NoTag "Headers:`n$HeadersString;`nBody:`n$Body"

        $Response = Invoke-RestMethod -Uri $RequestUrl -Headers $Headers `
            -Method $Method -ContentType 'application/json' `
            -Body $Body
        Write-Log '[Contrail]<= '
        Write-Log -NoTimestamp -NoTag "$Response"
        return $Response
    }

    hidden [PSObject] Send([String] $Method, [String] $Resource,
        [String] $Uuid, [Hashtable] $Request) {

        $RequestUrl = $this.GetResourceUrl($Resource, $Uuid)
        return $this.Send()
    }

    [PSObject] Get([String] $Resource, [String] $Uuid, [Hashtable] $Request) {
        return $this.Send('Get', $Resource, $Uuid, $Request)
    }

    [PSObject] Post([String] $Resource, [String] $Uuid, [Hashtable] $Request) {
        return $this.Send('Post', $Resource, $Uuid, $Request)
    }

    [PSObject] Put([String] $Resource, [String] $Uuid, [Hashtable] $Request) {
        return $this.Send('Put', $Resource, $Uuid, $Request)
    }

    [Void] Delete([String] $Resource, [String] $Uuid, [Hashtable] $Request) {
        $this.Send('Delete', $Resource, $Uuid, $Request)
    }

    [String] FqNameToUuid ([String] $Resource, [string[]] $FqName) {
        $Request = @{
            type    = $Resource
            fq_name = $FqName
        }
        $RequestUrl = $this.ContrailUrl + '/fqname-to-id'
        $Response = $this.Send('Post', $RequestUrl, $Request)
        return $Response.'uuid'
    }
}
