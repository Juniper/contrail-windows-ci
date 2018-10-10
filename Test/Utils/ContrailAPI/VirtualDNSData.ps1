class VirtualDNSData {
    [string] $DomainName;
    [boolean] $DynamicRecordsFromClient;
    [int] $DefaultTTL; # In seconds
    [boolean] $ExternalVisible;
    [boolean] $ReverseResolution;

    [ValidateSet("fixed","random","round-robin")]
    [string] $RecordOrder;

    [ValidateSet("dashed-ip","dashed-ip-tenant-name","vm-name","vm-name-tenant-name")]
    [string] $FloatingIpRecord;

    hidden Init([boolean] $DynamicRecordsFromClient, [string] $RecordOrder,
    [int] $DefaultTTL, [string] $FloatingIpRecord,
    [boolean] $ExternalVisible, [boolean] $ReverseResolution) {
        $this.DomainName = "default-domain";
        $this.DynamicRecordsFromClient = $DynamicRecordsFromClient;
        $this.RecordOrder = $RecordOrder;
        $this.DefaultTTL = $DefaultTTL;
        $this.FloatingIpRecord = $FloatingIpRecord;
        $this.ExternalVisible = $ExternalVisible;
        $this.ReverseResolution = $ReverseResolution;
    }

    VirtualDNSData() {
        $this.Init($true, "random", 86400,
            "dashed-ip-tenant-name", $false, $false)
    }

    VirtualDNSData([boolean] $DynamicRecordsFromClient, [string] $RecordOrder,
        [int] $DefaultTTL, [string] $FloatingIpRecord,
        [boolean] $ExternalVisible, [boolean] $ReverseResolution) {
        $this.Init($DynamicRecordsFromClient, $RecordOrder,
            $DefaultTTL, $FloatingIpRecord,
            $ExternalVisible, $ReverseResolution)
    }
}
