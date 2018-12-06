class FloatingIpPool : BaseResourceModel {
    [String] $Name
    [String] $NetworkName
    [String] $ProjectName
    [String] $DomainName = 'default-domain'

    [String] $ResourceName = 'floating-ip-pool'
    [String] $ParentType = 'virtual-network'

    FloatingIpPool([String] $Name, [String] $NetworkName, [String] $ProjectName) {
        $this.Name = $Name
        $this.NetworkName = $NetworkName
        $this.ProjectName = $ProjectName
    }

    [String[]] GetFqName() {
        return @($this.DomainName, $this.ProjectName, $this.NetworkName, $this.Name)
    }

    [Hashtable] GetRequest() {
        return @{
            'floating-ip-pool' = @{}
        }
    }
}
