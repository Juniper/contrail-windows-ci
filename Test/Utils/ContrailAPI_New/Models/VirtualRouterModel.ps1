class VirtualRouter : BaseResourceModel {
    [string] $Name;
    [string] $Ip;
    [string] $ParentName = 'default-global-system-config';

    VirtualRouter([String] $Name, [String] $Ip) {
        $this.Name = $Name
        $this.Ip = $Ip
    }

    [String[]] GetFQName() {
        return @($this.ParentName, $this.Name)
    }

    [String] $ResourceName = 'virtual-router'
    [String] $ParentType = 'global-system-config'

    [PSobject] GetRequest() {
        return @{
            'virtual-router' = @{
                virtual_router_ip_address = $this.Ip
            }
        }
    }
}
