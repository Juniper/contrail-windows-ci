class GlobalVrouterConfig : BaseRepoModel {
    [string] $Name = 'default-global-vrouter-config'
    [string] $SystemConfigName = 'default-global-system-config'
    [string[]] $EncapsulationPriorities = @()

    GlobalVrouterConfig([String[]] $EncapsulationPriorities) {
        $this.EncapsulationPriorities = $EncapsulationPriorities
    }

    [String[]] GetFQName() {
        return @($this.SystemConfigName, $this.Name)
    }
}
