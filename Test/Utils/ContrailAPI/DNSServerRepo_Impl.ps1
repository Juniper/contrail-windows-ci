class DNSServerRepo {
    [String] $ServerResourceName = "virtual-DNS"
    [String] $RecordResourceName = "virtual-DNS-record"

    [ContrailNetworkManager] $API

    DNSServerRepo ([ContrailNetworkManager] $API) {
        $this.API = $API
    }

    [String] AddContrailDNSServer([DNSServer] $DNSServer) {
        $VirtualDNS = @{
            domain_name                 = $DNSServer.DomainName
            dynamic_records_from_client = $DNSServer.DynamicRecordsFromClient
            record_order                = $DNSServer.RecordOrder
            default_ttl_seconds         = $DNSServer.DefaultTTLInSeconds
            floating_ip_record          = $DNSServer.FloatingIpRecord
            external_visible            = $DNSServer.ExternalVisible
            reverse_resolution          = $DNSServer.ReverseResolution
        }

        $Request = @{
            "virtual-DNS" = @{
                parent_type      = "domain"
                fq_name          = $DNSServer.GetFQName()
                virtual_DNS_data = $VirtualDNS
            }
        }

        $Response = $this.API.SendRequest("Post", $this.ServerResourceName, $null, $Request)
        $DNSServer.uuid = $Response.'virtual-DNS'.'uuid'
        return $DNSServer.uuid
    }

    RemoveContrailDNSServer([DNSServer] $DNSServer, [Boolean] $Force) {
        if(-not $DNSServer.Uuid) {
            $DNSServer.Uuid = $this.API.FQNameToUuid($this.ServerResourceName, $DNSServer.GetFQName())
        }

        if ($Force) {
            $RemoteDNSServer = $this.API.SendRequest("Get", $this.ServerResourceName, $DNSServer.Uuid, $null)

            if($RemoteDNSServer.'virtual-DNS'.PSobject.Properties.Name -contains 'virtual_DNS_records') {
                ForEach ($VirtualDNSRecord in ($RemoteDNSServer.'virtual-DNS'.'virtual_DNS_records')) {
                    $this.API.SendRequest("Delete", $this.RecordResourceName, $VirtualDNSRecord.'uuid', $null)
                }
            }

            if($RemoteDNSServer.'virtual-DNS'.PSobject.Properties.Name -contains 'network_ipam_back_refs') {
                $IPAMRepo = [IPAMRepo]::New($this.API)
                ForEach ($NetworkIPAM in ($RemoteDNSServer.'virtual-DNS'.'network_ipam_back_refs')) {
                    $IPAM = [IPAM]::New()
                    $IPAM.DomainName = $NetworkIPAM.to[0]
                    $IPAM.ProjectName = $NetworkIPAM.to[1]
                    $IPAM.Name = $NetworkIPAM.to[2]
                    $IPAM.DNSSettings = [NoneDNSSettings]::New()
                    $IPAMRepo.SetIpamDNSMode($IPAM)
                }
            }
        }

        $this.API.SendRequest("Delete", $this.ServerResourceName, $DNSServer.Uuid, $null)
    }

    [String] AddContrailDNSRecord ([DNSRecord] $DNSRecord) {

        $VirtualDNSRecord = @{
            record_name         = $DNSRecord.Name
            record_type         = $DNSRecord.Type
            record_class        = $DNSRecord.Class
            record_data         = $DNSRecord.Data
            record_ttl_seconds  = $DNSRecord.TTLInSeconds
        }

        $Request = @{
            "virtual-DNS-record" = @{
                parent_type             = "virtual-DNS"
                fq_name                 = $DNSRecord.GetFQName()
                virtual_DNS_record_data = $VirtualDNSRecord
            }
        }

        $Response = $this.API.SendRequest("Post", $this.RecordResourceName, $null, $Request)
        $DNSRecord.uuid = $Response.'virtual-DNS-record'.'uuid'
        return $DNSRecord.uuid
    }

    RemoveContrailDNSRecord ([DNSRecord] $DNSRecord) {
        if(-not $DNSRecord.Uuid) {
            Throw "You have to know DNS record UUID to delete it"
            # If we would be able to know Record InternalName, we would be able to do this
            # instead of throwing
            # $DNSRecord.Uuid = $this.API.FQNameToUuid($this.RecordResourceName, $DNSRecord.GetFQName())
        }

        $this.API.SendRequest("Delete", $this.RecordResourceName, $DNSRecord.Uuid, $null)
    }
}
