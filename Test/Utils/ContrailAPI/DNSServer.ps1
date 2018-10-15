. $PSScriptRoot\VirtualDNSData.ps1
. $PSScriptRoot\VirtualDNSRecordData.ps1
. $PSScriptRoot\..\ContrailNetworkManager.ps1

. $PSScriptRoot\DNSServerImpl.ps1

. $PSScriptRoot\Constants.ps1
. $PSScriptRoot\Global.ps1

function Add-ContrailDNSRecord {
    Param (
        [Parameter(Mandatory = $true)] [string] $ContrailUrl,
        [Parameter(Mandatory = $true)] [string] $AuthToken,
        [Parameter(Mandatory = $true)] [string] $DNSServerName,
        [Parameter(Mandatory = $true)] [VirtualDNSRecordData] $VirtualDNSRecordData
    )

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

    $RequestUrl = $ContrailUrl + "/virtual-DNS-records"
    $Response = Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post -ContentType "application/json" -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)

    return $Response.'virtual-DNS-record'.'uuid'
}

function Remove-ContrailDNSRecord {
    Param (
        [Parameter(Mandatory = $true)] [string] $ContrailUrl,
        [Parameter(Mandatory = $true)] [string] $AuthToken,
        [Parameter(Mandatory = $true)] [string] $DNSRecordUuid
    )

    $DNSRecordURl = $ContrailUrl + "/virtual-DNS-record/" + $DNSRecordUuid
    Invoke-RestMethod -Method Delete -Uri $DNSRecordURl -Headers @{"X-Auth-Token" = $AuthToken} | Out-Null
}

function Add-ContrailDNSServer {
    Param (
        [Parameter(Mandatory = $true)] [string] $ContrailUrl,
        [Parameter(Mandatory = $true)] [string] $AuthToken,
        [Parameter(Mandatory = $true)] [string] $DNSServerName,
        [Parameter(Mandatory = $false)] [VirtualDNSData] $VirtualDNSData = [VirtualDNSData]::new()
    )

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

    $RequestUrl = $ContrailUrl + "/virtual-DNSs"
    $Response = Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post -ContentType "application/json" -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)

    return $Response.'virtual-DNS'.'uuid'
}

function Remove-ContrailDNSServer {
    Param (
        [Parameter(Mandatory = $true)] [string] $ContrailUrl,
        [Parameter(Mandatory = $true)] [string] $AuthToken,
        [Parameter(Mandatory = $true)] [string] $DNSServerUuid,
        [Switch] $Force
    )

    $DNSServerURl = $ContrailUrl + "/virtual-DNS/" + $DNSServerUuid
    $DNSServer = Invoke-RestMethod -Method Get -Uri $DNSServerURl -Headers @{"X-Auth-Token" = $AuthToken}

    if ($Force) {

        if($DNSServer.'virtual-DNS'.PSobject.Properties.Name -contains 'virtual_DNS_records') {
            $VirtualDNSRecords = $DNSServer.'virtual-DNS'.'virtual_DNS_records'
            ForEach ($VirtualDNSRecord in $VirtualDNSRecords) {
                Invoke-RestMethod -Method Delete -Uri $VirtualDNSRecord.'href' `
                    -Headers @{"X-Auth-Token" = $AuthToken} | Out-Null
            }
        }

        if($DNSServer.'virtual-DNS'.PSobject.Properties.Name -contains 'network_ipam_back_refs') {
            $NetworkIPAMs = $DNSServer.'virtual-DNS'.'network_ipam_back_refs'
            ForEach ($NetworkIPAM in $NetworkIPAMs) {
                Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                    -IpamFQName $NetworkIPAM.'to' `
                    -DNSMode 'none'
            }
        }
    }

    Invoke-RestMethod -Method Delete -Uri $DNSServerURl -Headers @{"X-Auth-Token" = $AuthToken} | Out-Null
}
