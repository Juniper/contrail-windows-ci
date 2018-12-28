class OpenStackConfig {
    [string] $Username
    [string] $Password
    [string] $Project
    [string] $Address
    [int] $Port

    [string] AuthUrl() {
        return "http://$( $this.Address ):$( $this.Port )/v2.0"
    }
}

class ControllerConfig {
    [string] $Address
    [int] $RestApiPort
    [string] $AuthMethod

    [string] RestApiUrl() {
        return "http://$( $this.Address ):$( $this.RestApiPort )"
    }
}

class SystemConfig {
    [string] $AdapterName
    [string] $VHostName
    [string] $MgmtAdapterName
    [string] $ForwardingExtensionName

    [string] VMSwitchName() {
        return "Layered " + $this.AdapterName
    }
}

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
        $this.System = [Testenv]::ReadSystemConfig($TestenvConfFile)
        $this.OpenStack = [Testenv]::ReadOpenStackConfig($TestenvConfFile)
        $this.Controller = [Testenv]::ReadControllerConfig($TestenvConfFile)
        $this.Testbeds = [Testenv]::ReadTestbedsConfig($TestenvConfFile)
    }

    Testenv([SystemConfig] $System,
        [OpenStackConfig] $OpenStack,
        [ControllerConfig] $Controller) {

        $this.System = $System
        $this.OpenStack = $OpenStack
        $this.Controller = $Controller
    }

    hidden static [Ordered] ReadTestenvFile([string] $Path) {
        if (-not (Test-Path $Path)) {
            throw [System.Management.Automation.ItemNotFoundException] "Testenv config file not found at specified location."
        }
        $FileContents = Get-Content -Path $Path -Raw
        $Parsed = ConvertFrom-Yaml $FileContents
        return $Parsed
    }

    static [OpenStackConfig] ReadOpenStackConfig([string] $Path) {
        $Parsed = [Testenv]::ReadTestenvFile($Path)
        if ($Parsed.keys -notcontains 'OpenStack') {
            return $null
        }
        return [OpenStackConfig] $Parsed.OpenStack
    }

    static [ControllerConfig] ReadControllerConfig([string] $Path) {
        $Parsed = [Testenv]::ReadTestenvFile($Path)
        return [ControllerConfig] $Parsed.Controller
    }

    static [SystemConfig] ReadSystemConfig([string] $Path) {
        $Parsed = [Testenv]::ReadTestenvFile($Path)
        return [SystemConfig] $Parsed.System
    }

    static [Testbed[]] ReadTestbedsConfig([string] $Path) {
        $Parsed = [Testenv]::ReadTestenvFile($Path)
        return [Testbed[]] $Parsed.Testbeds
    }
}
