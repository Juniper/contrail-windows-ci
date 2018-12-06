class GlobalVrouterConfig : BaseResourceModel {
    [String] $Name = 'default-global-vrouter-config'
    [String] $SystemConfigName = 'default-global-system-config'
    [String[]] $EncapsulationPriorities = @()

    [String] $ResourceName = 'global-vrouter-config'
    [String] $ParentType = 'global-system-config'

    GlobalVrouterConfig([String[]] $EncapsulationPriorities) {
        $this.EncapsulationPriorities = $EncapsulationPriorities
    }

    [String[]] GetFqName() {
        return @($this.SystemConfigName, $this.Name)
    }

    [Hashtable] GetRequest() {
        return @{
            'global-vrouter-config' = @{
                encapsulation_priorities = @{
                    encapsulation = $this.EncapsulationPriorities
                }
            }
        }
    }
}
