class FloatingIpPool : BaseResourceModel {
    [String] $Name
    [String[]] $NetworkFqName

    [String] $ResourceName = 'floating-ip-pool'
    [String] $ParentType = 'virtual-network'

    FloatingIpPool([String] $Name, [String[]] $NetworkFqName) {
        $this.Name = $Name
        $this.NetworkFqName = $NetworkFqName
    }

    [String[]] GetFqName() {
        return ($this.NetworkFqName + @($this.Name))
    }

    [Hashtable] GetRequest() {
        return @{
            'floating-ip-pool' = @{}
        }
    }
}
