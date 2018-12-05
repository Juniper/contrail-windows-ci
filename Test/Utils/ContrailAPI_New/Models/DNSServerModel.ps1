# Those are just informative to show dependencies
#include "DNSRecordModel.ps1"

class DNSServer : BaseResourceModel {
    [string] $Name
    [string] $DomainName = "default-domain"
    [boolean] $DynamicRecordsFromClient = $true
    [int] $DefaultTTLInSeconds = 86400
    [boolean] $ExternalVisible = $false
    [boolean] $ReverseResolution = $false
    [string] $NextDNSServer = $null

    [ValidateSet("fixed", "random", "round-robin")]
    [string] $RecordOrder = "random";

    [ValidateSet("dashed-ip", "dashed-ip-tenant-name", "vm-name", "vm-name-tenant-name")]
    [string] $FloatingIpRecord = "dashed-ip-tenant-name";

    DNSServer([String] $Name) {
        $this.Name = $Name
        $this.Dependencies += [Dependency]::new('virtual-DNS-record', 'virtual_DNS_records')
    }

    [String[]] GetFQName() {
        return @($this.DomainName, $this.Name)
    }

    [String] $ResourceName = 'virtual-DNS'
    [String] $ParentType = 'domain'

    [PSobject] GetRequest() {
        $VirtualDNS = @{
            domain_name                 = $this.DomainName
            dynamic_records_from_client = $this.DynamicRecordsFromClient
            record_order                = $this.RecordOrder
            default_ttl_seconds         = $this.DefaultTTLInSeconds
            floating_ip_record          = $this.FloatingIpRecord
            external_visible            = $this.ExternalVisible
            reverse_resolution          = $this.ReverseResolution
        }
        if ($this.NextDNSServer) {
            $VirtualDNS += @{
                next_virtual_DNS = $this.NextDNSServer
            }
        }

        $Request = @{
            'virtual-DNS' = @{
                virtual_DNS_data = $VirtualDNS
            }
        }

        return $Request
    }
}
