class FloatingIpPool : BaseRepoModel {
    [string] $Name
    [string] $NetworkName
    [string] $ProjectName
    [string] $DomainName = 'default-domain'

    FloatingIpPool([string] $Name, [string] $NetworkName, [string] $ProjectName) {
        $this.Name = $Name
        $this.NetworkName = $NetworkName
        $this.ProjectName = $ProjectName
    }

    [String[]] GetFQName() {
        return @($this.DomainName, $this.ProjectName, $this.NetworkName, $this.Name)
    }
}
