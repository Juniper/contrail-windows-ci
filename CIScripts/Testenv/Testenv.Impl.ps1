class Testenv {
    [SystemConfig] $System
    [OpenStackConfig] $OpenStack
    [ControllerConfig] $Controller
    [Testbed[]] $Testbeds

    [PSSessionT[]] $Sessions

    [Void] Initialize() {
        $this.Sessions = New-RemoteSessions -VMs $this.Testbeds
        Set-ConfAndLogDir -Sessions $this.Sessions
        Sync-MicrosoftDockerImagesOnTestbeds -Sessions $this.Sessions
    }

    Testenv([String] $TestenvConfFile) {
        $this.System = [SystemConfig]::LoadFromFile($TestenvConfFile)
        $this.OpenStack = [OpenStackConfig]::LoadFromFile($TestenvConfFile)
        $this.Controller = [ControllerConfig]::LoadFromFile($TestenvConfFile)
        $this.Testbeds = [Testbed]::LoadFromFile($TestenvConfFile)
    }
}
