class FloatingIpPool : BaseResourceModel {
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

    [String] $ResourceName = 'floating-ip-pool'
    [String] $ParentType = 'virtual-network'

    [PSobject] GetRequest() {
        return @{
            'floating-ip-pool' = @{}
        }
    }
}
