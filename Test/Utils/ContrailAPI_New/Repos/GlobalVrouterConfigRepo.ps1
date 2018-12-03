class GlobalVrouterConfigRepo : BaseRepo {
    [String] $ResourceName = 'global-vrouter-config'

    GlobalVrouterConfigRepo([ContrailNetworkManager] $API) : base($API) {}

    [Void] SetEncapPriorities([GlobalVrouterConfig] $Config) {
        $Uuid = $this.API.FQNameToUuid($this.ResourceName, $Config.GetFQName())

        $Request = @{
            'global-vrouter-config' = @{
                parent_type = 'global-system-config'
                fq_name = $Config.GetFQName()
                encapsulation_priorities = @{
                    encapsulation = $Config.EncapsulationPriorities
                }
            }
        }

        $this.API.Put($this.ResourceName, $Uuid, $Request) | Out-Null
    }
}
