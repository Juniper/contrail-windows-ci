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

class NetworkIPAM {
    [ContrailNetworkManager] $API

    NetworkIPAM (
        [ContrailNetworkManager] $API
    )
    {
        $this.API = $API
    }

    [PSObject] AddTenantDNSInformation (
        [string[]] $TenantServersIPAddresses,
                   $Request
    )
    {
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

    [PSObject] AddVirtualDNSInformation (
        [string[]] $VirtualServerFQName,
        [string] $VirtualServerUuid,
        [string] $VirtualServerUrl,
                 $Request
    )
    {
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

    SetIpamDNSMode (
        [string[]] $IpamFQName,
        # [ValidateSet("none","default-dns-server","tenant-dns-server","virtual-dns-server")]
        [string] $DNSMode,
        [DNSOptions] $Options
    )
    {
        $Request = @{
            "network-ipam" = @{
                "network_ipam_mgmt" = @{"ipam_dns_method" = $DNSMode}
                "virtual_DNS_refs"  = @()
            }
        }

        if ($DNSMode -ceq 'tenant-dns-server')     {
            $TenantServersIPAddresses = $Options.ServersIPs
            if(-not $TenantServersIPAddresses) {
                throw "You need to specify list of DNS servers to be used"
            }
            $this.AddTenantDNSInformation($TenantServersIPAddresses, $Request)
        }
        elseif ($DNSMode -ceq 'virtual-dns-server')     {
            $VirtualServerName = $Options.ServerName
            if(-not $VirtualServerName) {
                throw "You need to specify Virtual DNS Server to be used"
            }

            $VirtualServerFQName = @("default-domain", $VirtualServerName)
            $VirtualServerUuid = $this.API.FQNameToUuid("virtual-DNS", $VirtualServerFQName)
            $VirtualServerUrl = $this.API.ContrailUrl + "/virtual-DNS/" + $VirtualServerUuid

            $this.AddVirtualDNSInformation($VirtualServerFQName, $VirtualServerUuid, $VirtualServerUrl, $Request)
        }

        $IpamUuid = $this.API.FQNameToUuid("network-ipam", $IpamFQName)

        $this.API.SendRequest("Put", "network-ipam", $IpamUuid, $Request)
    }
}
