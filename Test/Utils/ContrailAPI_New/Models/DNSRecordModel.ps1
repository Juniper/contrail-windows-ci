class DNSRecord : BaseResourceModel {
    [string] $Name
    [string[]] $ServerFQName

    [ValidateSet("A", "AAAA", "CNAME", "PTR", "NS", "MX")]
    [string] $Type
    [string] $HostName
    [string] $Data
    [string] $Class = "IN"
    [int] $TTLInSeconds = 86400

    DNSRecord([string] $Name, [string[]] $ServerFQName, [string] $HostName, [string] $Data, [string] $Type) {
        $this.Name = $Name
        $this.ServerFQName = $ServerFQName
        $this.HostName = $HostName
        $this.Data = $Data
        $this.Type = $Type
    }

    [String[]] GetFQName() {
        return $this.ServerFQName + @($this.Name)
    }

    [String] $ResourceName = 'virtual-DNS-record'
    [String] $ParentType = 'virtual-DNS'

    [PSobject] GetRequest() {
        $VirtualDNSRecord = @{
            record_name         = $this.HostName
            record_type         = $this.Type
            record_class        = $this.Class
            record_data         = $this.Data
            record_ttl_seconds  = $this.TTLInSeconds
        }

        $Request = @{
            'virtual-DNS-record' = @{
                virtual_DNS_record_data = $VirtualDNSRecord
            }
        }

        return $Request
    }
}
