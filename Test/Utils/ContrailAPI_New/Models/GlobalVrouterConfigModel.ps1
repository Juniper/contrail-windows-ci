class GlobalVrouterConfig : BaseResourceModel {
    [string] $Name = 'default-global-vrouter-config'
    [string] $SystemConfigName = 'default-global-system-config'
    [string[]] $EncapsulationPriorities = @()

    GlobalVrouterConfig([String[]] $EncapsulationPriorities) {
        $this.EncapsulationPriorities = $EncapsulationPriorities
    }

    [String[]] GetFQName() {
        return @($this.SystemConfigName, $this.Name)
    }

    [String] $ResourceName = 'global-vrouter-config'
    [String] $ParentType = 'global-system-config'

    [PSobject] GetRequest() {
        return @{
            'global-vrouter-config' = @{
                encapsulation_priorities = @{
                    encapsulation = $this.EncapsulationPriorities
                }
            }
        }
    }
}
