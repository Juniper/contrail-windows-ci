class DNSRecordRepo : BaseRepo {
    [String] $ResourceName = 'virtual-DNS-record'

    DNSRecordRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([DNSRecord] $DNSRecord) {
        $VirtualDNSRecord = @{
            record_name         = $DNSRecord.HostName
            record_type         = $DNSRecord.Type
            record_class        = $DNSRecord.Class
            record_data         = $DNSRecord.Data
            record_ttl_seconds  = $DNSRecord.TTLInSeconds
        }

        $Request = @{
            'virtual-DNS-record' = @{
                parent_type             = 'virtual-DNS'
                fq_name                 = $DNSRecord.GetFQName()
                virtual_DNS_record_data = $VirtualDNSRecord
            }
        }

        return $Request
    }
}
