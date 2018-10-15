class DNSServer {
    [ContrailNetworkManager] $API

    DNSServer (
        [ContrailNetworkManager] $API
    )
    {
        $this.API = $API
    }

    [String] AddContrailDNSRecord (
        [string] $DNSServerName,
        [VirtualDNSRecordData] $VirtualDNSRecordData
    )
    {
        $VirtualDNSRecord = @{
            record_name         = $VirtualDNSRecordData.RecordName
            record_type         = $VirtualDNSRecordData.RecordType
            record_class        = $VirtualDNSRecordData.RecordClass
            record_data         = $VirtualDNSRecordData.RecordData
            record_ttl_seconds  = $VirtualDNSRecordData.RecordTTLInSeconds
        }

        $Request = @{
            "virtual-DNS-record" = @{
                parent_type             = "virtual-DNS"
                fq_name                 = @("default-domain", $DNSServerName, [guid]::NewGuid())
                virtual_DNS_record_data = $VirtualDNSRecord
            }
        }

        $Response = $this.API.SendRequest("Post", "virtual-DNS-record", $null, $Request)

        return $Response.'virtual-DNS-record'.'uuid'
    }

    [String] AddContrailDNSRecord (
        [String] $DNSServerName,
        [String] $HostName,
        [String] $HostIP
    )
    {
        $VirtualDNSRecordData = [VirtualDNSRecordData]::new($HostName, $HostIP, "A")
        return $this.AddContrailDNSRecord($DNSServerName, $VirtualDNSRecordData)
    }

    RemoveContrailDNSRecord (
        [String] $DNSRecordUuid
    )
    {
        $this.API.SendRequest("Delete", "virtual-DNS-record", $DNSRecordUuid, $null)
    }

    [String] AddContrailDNSServer(
        [string] $DNSServerName,
        [VirtualDNSData] $VirtualDNSData
    )
    {
        $VirtualDNS = @{
            domain_name                 = $VirtualDNSData.DomainName
            dynamic_records_from_client = $VirtualDNSData.DynamicRecordsFromClient
            record_order                = $VirtualDNSData.RecordOrder
            default_ttl_seconds         = $VirtualDNSData.DefaultTTLInSeconds
            floating_ip_record          = $VirtualDNSData.FloatingIpRecord
            external_visible            = $VirtualDNSData.ExternalVisible
            reverse_resolution          = $VirtualDNSData.ReverseResolution
        }

        $Request = @{
            "virtual-DNS" = @{
                parent_type      = "domain"
                fq_name          = @("default-domain", $DNSServerName)
                virtual_DNS_data = $VirtualDNS
            }
        }

        $Response = $this.API.SendRequest("Post", "virtual-DNS", $null, $Request)

        return $Response.'virtual-DNS'.'uuid'
    }

    [String] AddContrailDNSServer (
        [string] $DNSServerName
    )
    {
        return $this.AddContrailDNSServer($DNSServerName, [VirtualDNSData]::new())
    }

    RemoveContrailDNSServer (
        [string] $DNSServerUuid,
        [Boolean] $Force
    )
    {
        $DNSServer = $this.API.SendRequest("Get", "virtual-DNS", $DNSServerUuid, $null)

        if ($Force) {

            if($DNSServer.'virtual-DNS'.PSobject.Properties.Name -contains 'virtual_DNS_records') {
                $VirtualDNSRecords = $DNSServer.'virtual-DNS'.'virtual_DNS_records'
                ForEach ($VirtualDNSRecord in $VirtualDNSRecords) {
                    $this.API.SendRequest("Delete", "virtual-DNS-record", $VirtualDNSRecord.'uuid', $null)
                }
            }

            if($DNSServer.'virtual-DNS'.PSobject.Properties.Name -contains 'network_ipam_back_refs') {
                $NetworkIPAMs = $DNSServer.'virtual-DNS'.'network_ipam_back_refs'
                ForEach ($NetworkIPAM in $NetworkIPAMs) {
                    Set-IpamDNSMode -ContrailUrl $this.API.ContrailUrl -AuthToken $this.API.AuthToken `
                        -IpamFQName $NetworkIPAM.'to' `
                        -DNSMode 'none'
                }
            }
        }

        $this.API.SendRequest("Delete", "virtual-DNS", $DNSServerUuid, $null)
    }
}
