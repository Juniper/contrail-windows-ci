class DNSServerRepo : BaseRepo {
    [String] $ResourceName = 'virtual-DNS'

    DNSServerRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([DNSServer] $DNSServer) {
        $VirtualDNS = @{
            domain_name                 = $DNSServer.DomainName
            dynamic_records_from_client = $DNSServer.DynamicRecordsFromClient
            record_order                = $DNSServer.RecordOrder
            default_ttl_seconds         = $DNSServer.DefaultTTLInSeconds
            floating_ip_record          = $DNSServer.FloatingIpRecord
            external_visible            = $DNSServer.ExternalVisible
            reverse_resolution          = $DNSServer.ReverseResolution
        }
        if($DNSServer.NextDNSServer) {
            $VirtualDNS += @{
                next_virtual_DNS = $DNSServer.NextDNSServer
            }
        }

        $Request = @{
            'virtual-DNS' = @{
                parent_type      = 'domain'
                fq_name          = $DNSServer.GetFQName()
                virtual_DNS_data = $VirtualDNS
            }
        }

        return $Request
    }

    [void] RemoveDependencies([DNSServer] $DNSServer) {
        $Uuid = $this.API.FQNameToUuid($this.ResourceName, $DNSServer.GetFQName())
        $Response = $this.API.Get($this.ResourceName, $Uuid, $null)
        $Props = $Response.$($this.ResourceName).PSobject.Properties.Name

        if($Props -contains 'virtual_DNS_records') {
            ForEach ($Child in $Response.$($this.ResourceName).'virtual_DNS_records') {
                $this.API.Delete('virtual-DNS-record', $Child.'uuid', $null)
            }
        }
        #  TODO
        # if($Props -contains 'network_ipam_back_refs') {
        #     ForEach ($Child in $Response.'virtual-DNS'.'network_ipam_back_refs') {
        #         # $this.API.Delete('virtual-DNS-record', $Child.'uuid', $null)
        #         $IPAMRepo = [IPAMRepo]::New($this.API)
        #         $IPAM = [IPAM]::New()
        #         $IPAM.DomainName = $NetworkIPAM.to[0]
        #         $IPAM.ProjectName = $NetworkIPAM.to[1]
        #         $IPAM.Name = $NetworkIPAM.to[2]
        #         $IPAM.DNSSettings = [NoneDNSSettings]::New()
        #         $IPAMRepo.SetIpamDNSMode($IPAM)
        #     }
        # }
    }
}
