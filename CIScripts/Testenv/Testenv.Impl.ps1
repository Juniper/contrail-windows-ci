class Testenv {
    [SystemConfig] $System
    [OpenStackConfig] $OpenStack
    [ControllerConfig] $Controller
    [Testbed[]] $Testbeds

    [PSSessionT[]] $Sessions = $null

    [System.Collections.Stack] $CleanupStacks = [System.Collections.Stack]::new()
    [MultiNode] $Multinode = $null
    [LogSource[]] $LogSources = $null
    [ContrailRepo] $ContrailRepo = $null

    Testenv([String] $TestenvConfFile) {
        $this.System = [SystemConfig]::LoadFromFile($TestenvConfFile)
        $this.OpenStack = [OpenStackConfig]::LoadFromFile($TestenvConfFile)
        $this.Controller = [ControllerConfig]::LoadFromFile($TestenvConfFile)
        $this.Testbeds = [Testbed]::LoadFromFile($TestenvConfFile)
    }

    [Void] Initialize() {
        $CleanupStack = $this.NewCleanupStack()
        $this.Sessions = New-RemoteSessions -VMs $this.Testbeds
        $CleanupStack.Push({Param([PSSessionT[]] $Sessions) Remove-PSSession $Sessions}, @(, $this.Sessions))
        Set-ConfAndLogDir -Sessions $this.Sessions
        Sync-MicrosoftDockerImagesOnTestbeds -Sessions $this.Sessions
    }

    [Void] Initialize_New([String] $LogDir, [String] $ContrailProject, [Bool] $InstallComponents) {
        $CleanupStack = $this.NewCleanupStack()

        Initialize-PesterLogger -OutDir $LogDir

        $this.MultiNode = New-MultiNodeSetup `
            -Testbeds $this.Testbeds `
            -ControllerConfig $this.Controller `
            -OpenStackConfig $this.OpenStack `
            -ContrailProject $ContrailProject
        $CleanupStack.Push(${function:Remove-MultiNodeSetup}, @($this.MultiNode))

        [LogSource[]] $this.LogSources = New-ComputeNodeLogSources -Sessions $this.Sessions

        if ($InstallComponents) {
            $CleanupStack.Push(${function:Clear-Logs}, @(, $this.LogSources))
            foreach ($Session in $this.Sessions) {
                Initialize-ComputeNode `
                    -Session $Session `
                    -Configs $this
                $CleanupStack.Push(${function:Clear-ComputeNode}, @($Session, $this.System))
            }
        }

        $this.ContrailRepo = [ContrailRepo]::new($this.MultiNode.ContrailRestApi)
    }

    [CleanupStack] NewCleanupStack() {
        $CleanupStack = [CleanupStack]::new()
        $this.CleanupStacks.Push($CleanupStack)
        return $CleanupStack
    }

    [Void] Cleanup() {
        foreach ($CleanupStack in $this.CleanupStacks) {
            $CleanupStack.RunCleanup($this.ContrailRepo)
        }
    }
}
