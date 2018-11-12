. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1

. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\Configuration.ps1
. $PSScriptRoot\Installation.ps1
. $PSScriptRoot\Service.ps1
. $PSScriptRoot\..\DockerNetwork\DockerNetwork.ps1

function Initialize-ComputeNode {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [TestenvConfigs] $Configs,
        [Parameter(Mandatory=$false)] [bool] $PrepareEnv=$true
    )

    if ($PrepareEnv) {
        Write-Log "Installing components on testbed..."
        Install-ComputeServices -Session $Session `
            -SystemConfig $Configs.System `
            -OpenStackConfig $Configs.OpenStack `
            -ControllerConfig $Configs.Controller
    } else {
        Write-Log "Not performing environment setup because PrepareEnv flag is set to $PrepareEnv"
    }
}

function Clear-ComputeNode {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig,
        [Parameter(Mandatory=$false)] [bool] $PrepareEnv=$true
    )

    if ($PrepareEnv) {
        Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig

        Clear-Logs -LogSources (New-FileLogSource -Path (Get-ComputeLogsPath) -Sessions $Session)

        Write-Log "Uninstalling components from testbed..."
        Uninstall-Components -Session $Session
    } else {
        Write-Log "Not performing environment cleanup because PrepareEnv flag is set to $PrepareEnv"
    }
}

function Initialize-DockerNetworks {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [TestenvConfigs] $Configs,
        [Parameter(Mandatory=$true)] [Network[]] $Networks
    )
    foreach ($Network in $Networks) {
        $ID = New-DockerNetwork -Session $Session `
            -TenantName $Configs.Controller.DefaultProject `
            -Name $Network.Name `
            -Subnet "$( $Network.Subnet.IpPrefix )/$( $Network.Subnet.IpPrefixLen )"

        Write-Log "Created network id: $ID"
    }
}

function Install-ComputeServices {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig,
        [Parameter(Mandatory = $true)] [OpenStackConfig] $OpenStackConfig,
        [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig
    )
    Install-Components -Session $Session

    Initialize-ComputeServices `
        -Session $Session `
        -SystemConfig $SystemConfig `
        -OpenStackConfig $OpenStackConfig `
        -ControllerConfig $ControllerConfig
}

function Initialize-ComputeServices {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig,
        [Parameter(Mandatory = $true)] [OpenStackConfig] $OpenStackConfig,
        [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig
    )

    New-NodeMgrConfigFile -Session $Session -ControllerIP $ControllerConfig.Address

    New-CNMPluginConfigFile -Session $Session `
        -AdapterName $SystemConfig.AdapterName `
        -OpenStackConfig $OpenStackConfig `
        -ControllerConfig $ControllerConfig

    Initialize-DriverAndExtension -Session $Session `
        -SystemConfig $SystemConfig

    New-AgentConfigFile -Session $Session `
        -ControllerConfig $ControllerConfig `
        -SystemConfig $SystemConfig

    Start-AgentService -Session $Session
}
