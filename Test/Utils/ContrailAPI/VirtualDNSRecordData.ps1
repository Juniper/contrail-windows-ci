class VirtualDNSRecordData {
    [string] $RecordName;
    [string] $RecordClass;
    [string] $RecordData;
    [int] $RecordTTL; # In seconds

    [ValidateSet("A","AAAA","CNAME","PTR","NS","MX")]
    [string] $RecordType;

    hidden Init([string] $RecordName, [string] $RecordData,
        [string] $RecordType, [int] $RecordTTL,
        [string] $RecordClass) {

        $this.RecordName = $RecordName;
        $this.RecordData = $RecordData;
        $this.RecordType = $RecordType;
        $this.RecordTTL = $RecordTTL;
        $this.RecordClass = $RecordClass;
    }

    hidden Init([string] $RecordName, [string] $RecordData,
        [string] $RecordType, [int] $RecordTTL) {

        $this.Init($RecordName, $RecordData, $RecordType, $RecordTTL, "IN")
    }

    hidden Init([string] $RecordName, [string] $RecordData,
        [string] $RecordType) {

        $this.Init($RecordName, $RecordData, $RecordType, 86400);
    }

    VirtualDNSRecordData([string] $RecordName, [string] $RecordData, [string] $RecordType,
        [int] $RecordTTL) {

        $this.Init($RecordName, $RecordData, $RecordType, $RecordTTL);
    }

    VirtualDNSRecordData([string] $RecordName, [string] $RecordData, [string] $RecordType) {
        $this.Init($RecordName, $RecordData, $RecordType);
    }
}
