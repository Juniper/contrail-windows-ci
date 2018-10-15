. $PSScriptRoot\Constants.ps1
. $PSScriptRoot\Global.ps1

class DNSOptions {
}

class TenantDNSOptions : DNSOptions {
    [string[]] $ServersIPs;
    TenantDNSOptions([string[]] $ServersIPs) {
        $this.ServersIPs = $ServersIPs
    }
}

class VirtualDNSOptions : DNSOptions {
    [string] $ServerName
    VirtualDNSOptions([string] $ServerName) {
        $this.ServerName = $ServerName
    }
}

function Add-TenantDNSInformation {
    Param (
        [Parameter(Mandatory = $false)] [string[]] $TenantServersIPAddresses = @(),
        [Parameter(Mandatory = $true)] $Request
    )
    $DNSServer = @{
        "ipam_dns_server" = @{
            "tenant_dns_server_address" = @{
                "ip_address" = $TenantServersIPAddresses
            }
        }
    }

    $Request."network-ipam"."network_ipam_mgmt" += $DNSServer

    return $Request
}

function Add-VirtualDNSInformation {
    Param (
        [Parameter(Mandatory = $false)] [string[]] $VirtualServerFQName,
        [Parameter(Mandatory = $false)] [string] $VirtualServerUuid,
        [Parameter(Mandatory = $false)] [string] $VirtualServerUrl,
        [Parameter(Mandatory = $true)] $Request
    )

    $DNSServer = @{
        "ipam_dns_server" = @{
            "virtual_dns_server_name" = [string]::Join(":",$VirtualServerFQName)
        }
    }
    $Request."network-ipam"."network_ipam_mgmt" += $DNSServer

    $VirtualServerRef = @{
        "href" = $VirtualServerUrl
        "uuid" = $VirtualServerUuid
        "to"   = $VirtualServerFQName

    }

    $Request."network-ipam"."virtual_DNS_refs" = @($VirtualServerRef)

    return $Request
}

function Set-IpamDNSMode {
    Param (
        [Parameter(Mandatory = $true)] [string] $ContrailUrl,
        [Parameter(Mandatory = $true)] [string] $AuthToken,
        [Parameter(Mandatory = $true)] [string[]] $IpamFQName,
        [Parameter(Mandatory = $true)]
            [ValidateSet("none","default-dns-server","tenant-dns-server","virtual-dns-server")]
            [string] $DNSMode,
        [Parameter(Mandatory = $false)] [DNSOptions] $Options
    )

    $Request = @{
        "network-ipam" = @{
            "network_ipam_mgmt" = @{"ipam_dns_method" = $DNSMode}
            "virtual_DNS_refs"  = @()
        }
    }

    if ($DNSMode -ceq 'tenant-dns-server')     {
        $TenantServersIPAddresses = $Options.ServersIPs
        Add-TenantDNSInformation -TenantServersIPAddresses $TenantServersIPAddresses -Request $Request
    }
    elseif ($DNSMode -ceq 'virtual-dns-server')     {
        $VirtualServerName = $Options.ServerName
        if(-not $VirtualServerName) {
            throw "You need to specify Virtual DNS Server to be used"
        }

        $VirtualServerFQName = @("default-domain", $VirtualServerName)
        $VirtualServerUuid = FQNameToUuid -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -Type 'virtual-DNS' -FQName $VirtualServerFQName
        $VirtualServerUrl = $ContrailUrl + "/virtual-DNS/" + $VirtualServerUuid

        Add-VirtualDNSInformation -VirtualServerFQName $VirtualServerFQName -VirtualServerUuid $VirtualServerUuid `
            -VirtualServerUrl $VirtualServerUrl -Request $Request
    }


    $IpamUuid = FQNameToUuid -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
        -Type 'network-ipam' -FQName $IpamFQName
    $RequestUrl = $ContrailUrl + "/network-ipam/" + $IpamUuid
    $Response = Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Put -ContentType "application/json" -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)

    return $Response.'network-ipam'.'uuid'
}