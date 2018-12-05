class DNSRecord : BaseRepoModel {
    [string] $Name
    [string[]] $ServerFQName

    [ValidateSet("A","AAAA","CNAME","PTR","NS","MX")]
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
}
