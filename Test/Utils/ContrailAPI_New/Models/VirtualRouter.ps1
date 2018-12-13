class VirtualRouter : BaseResourceModel {
    [String] $Name
    [String] $Ip
    [String] $ParentName = 'default-global-system-config'
    
    [String] $ResourceName = 'virtual-router'
    [String] $ParentType = 'global-system-config'

    VirtualRouter([String] $Name, [String] $Ip) {
        $this.Name = $Name
        $this.Ip = $Ip
    }

    [String[]] GetFqName() {
        return @($this.ParentName, $this.Name)
    }

    [Hashtable] GetRequest() {
        return @{
            'virtual-router' = @{
                virtual_router_ip_address = $this.Ip
            }
        }
    }
}
