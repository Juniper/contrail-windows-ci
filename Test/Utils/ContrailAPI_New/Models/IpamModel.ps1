class IPAM : BaseResourceModel {
    [string] $Name = "default-network-ipam"
    [string] $DomainName = "default-domain"
    [string] $ProjectName = "default-project"
    [IPAMDNSSettings] $DNSSettings = [NoneDNSSettings]::New();

    [String[]] GetFQName() {
        return @($this.DomainName, $this.ProjectName, $this.Name)
    }

    [String] $ResourceName = 'network-ipam'
    [String] $ParentType = 'project'

    [PSobject] GetRequest() {
        $Request = @{
            "network-ipam" = @{
                "network_ipam_mgmt" = @{"ipam_dns_method" = $this.DNSSettings.DNSMode }
                "virtual_DNS_refs"  = @()
            }
        }

        if ($this.DNSSettings.DNSMode -ceq 'tenant-dns-server') {
            $this.AddTenantDNSInformation($Request)
        }
        elseif ($this.DNSSettings.DNSMode -ceq 'virtual-dns-server') {
            $this.AddVirtualDNSInformation($Request)
        }

        return $Request
    }

    hidden [void] AddTenantDNSInformation ($Request) {
        $DNSServer = @{
            "ipam_dns_server" = @{
                "tenant_dns_server_address" = @{
                    "ip_address" = $this.DNSSettings.ServersIPs
                }
            }
        }

        $Request."network-ipam"."network_ipam_mgmt" += $DNSServer
    }

    hidden [void] AddVirtualDNSInformation ($Request) {

        # $VirtualServerUuid = $this.API.FQNameToUuid("virtual-DNS", $this.DNSSettings.FQServerName)
        # $VirtualServerUrl = $this.API.GetResourceUrl("virtual-DNS", $VirtualServerUuid)

        $DNSServer = @{
            "ipam_dns_server" = @{
                "virtual_dns_server_name" = [string]::Join(":", $this.DNSSettings.FQServerName)
            }
        }
        $Request."network-ipam"."network_ipam_mgmt" += $DNSServer

        $VirtualServerRef = @{
            # "href" = $VirtualServerUrl
            # "uuid" = $VirtualServerUuid
            "to"   = $this.DNSSettings.FQServerName
        }

        $Request."network-ipam"."virtual_DNS_refs" = @($VirtualServerRef)
    }
}

class IPAMDNSSettings {
    [string] $DNSMode
}

class NoneDNSSettings : IPAMDNSSettings {
    NoneDNSSettings() {
        $this.DNSMode = "none"
    }
}

class DefaultDNSSettings : IPAMDNSSettings {
    DefaultDNSSettings() {
        $this.DNSMode = "default-dns-server"
    }
}

class TenantDNSSettings : IPAMDNSSettings {
    [string[]] $ServersIPs
    TenantDNSSettings([string[]] $ServersIPs) {
        if(-not $ServersIPs) {
            Throw "You need to specify DNS servers"
        }
        $this.ServersIPs = $ServersIPs
        $this.DNSMode = "tenant-dns-server"
    }
}

class VirtualDNSSettings : IPAMDNSSettings {
    [string[]] $FQServerName
    VirtualDNSSettings([String[]] $FQServerName) {
        if(-not $FQServerName) {
            Throw "You need to specify DNS server"
        }
        $this.FQServerName = $FQServerName
        $this.DNSMode = "virtual-dns-server"
    }
}
