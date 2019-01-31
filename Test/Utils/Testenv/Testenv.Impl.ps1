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

    Initialize([String] $TestenvConfFile, [String] $LogDir, [String] $ContrailProject, [Bool] $InstallComponents) {
        Initialize-PesterLogger -OutDir $LogDir

        Write-Log 'Reading config files'
        $this.System = [SystemConfig]::LoadFromFile($TestenvConfFile)
        $this.OpenStack = [OpenStackConfig]::LoadFromFile($TestenvConfFile)
        $this.Controller = [ControllerConfig]::LoadFromFile($TestenvConfFile)
        $this.Testbeds = [Testbed]::LoadFromFile($TestenvConfFile)

        $CleanupStack = $this.NewCleanupStack()

        Write-Log 'Creating sessions'
        $this.Sessions = New-RemoteSessions -VMs $this.Testbeds
        $CleanupStack.Push( {Param([PSSessionT[]] $Sessions) Remove-PSSession $Sessions}, @(, $this.Sessions))

        Write-Log 'Preparing testbeds'
        Set-ConfAndLogDir -Sessions $this.Sessions
        Sync-MicrosoftDockerImagesOnTestbeds -Sessions $this.Sessions

        Write-Log 'Setting up Contrail'
        $this.MultiNode = New-MultiNodeSetup `
            -Testbeds $this.Testbeds `
            -ControllerConfig $this.Controller `
            -AuthConfig $this.OpenStack `
            -ContrailProject $ContrailProject `
            -CleanupStack $CleanupStack

        Write-Log 'Creating log sources'
        [LogSource[]] $this.LogSources = New-ComputeNodeLogSources -Sessions $this.Sessions
        if ($InstallComponents) {
            $CleanupStack.Push(${function:Clear-Logs}, @(, $this.LogSources))
        }
        $CleanupStack.Push(${function:Merge-Logs}, @(, $this.LogSources))

        if ($InstallComponents) {
            foreach ($Session in $this.Sessions) {
                Initialize-ComputeNode `
                    -Session $Session `
                    -Configs $this `
                    -CleanupStack $CleanupStack
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
