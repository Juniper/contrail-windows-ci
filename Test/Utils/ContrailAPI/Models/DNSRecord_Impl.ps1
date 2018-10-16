class DNSRecord {
    [ValidateSet("A","AAAA","CNAME","PTR","NS","MX")]
    [string] $Type;
    [string] $Name;
    [string] $Data;
    [string] $Class = "IN";
    [int] $TTLInSeconds = 86400;
    [string[]] $FQServerName;
    [string] $InternalName = [GUID]::NewGuid();
    [string] $Uuid;

    DNSRecord([string] $Name, [string] $Data, [string] $Type, [string[]] $FQServerName) {
        $this.Name = $Name
        $this.Data = $Data
        $this.Type = $Type
        $this.FQServerName = $FQServerName
    }

    [String[]] GetFQName() {
        return $this.FQServerName + @($this.InternalName)
    }
}
