. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1

. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\Configuration.ps1
. $PSScriptRoot\Installation.ps1
. $PSScriptRoot\Service.ps1
. $PSScriptRoot\..\DockerNetwork\DockerNetwork.ps1

function Set-ConfAndLogDir {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )
    $ConfigDirPath = Get-DefaultConfigDir
    $LogDirPath = Get-ComputeLogsDir

    foreach ($Session in $Sessions) {
        Invoke-Command -Session $Session -ScriptBlock {
            New-Item -ItemType Directory -Path $using:ConfigDirPath -Force | Out-Null
            New-Item -ItemType Directory -Path $using:LogDirPath -Force | Out-Null
        } | Out-Null
    }
}

function Initialize-ComputeNode {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [Testenv] $Configs
    )

    Write-Log "Installing components on testbed..."
    Install-Components -Session $Session

    Write-Log "Initializing components on testbed..."
    Initialize-ComputeServices -Session $Session `
        -SystemConfig $Configs.System `
        -OpenStackConfig $Configs.OpenStack `
        -ControllerConfig $Configs.Controller
}

function Clear-ComputeNode {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig

    Write-Log "Uninstalling components from testbed..."
    Uninstall-Components -Session $Session
}

function Initialize-ComputeServices {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig,
        [Parameter(Mandatory = $false)] [OpenStackConfig] $OpenStackConfig,
        [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig
    )

    New-NodeMgrConfigFile -Session $Session  `
        -ControllerIP $ControllerConfig.Address `
        -MgmtAdapterName $SystemConfig.MgmtAdapterName

    New-CNMPluginConfigFile -Session $Session `
        -AdapterName $SystemConfig.AdapterName `
        -OpenStackConfig $OpenStackConfig `
        -ControllerConfig $ControllerConfig

    Initialize-CnmPluginAndExtension -Session $Session `
        -SystemConfig $SystemConfig

    New-AgentConfigFile -Session $Session `
        -ControllerConfig $ControllerConfig `
        -SystemConfig $SystemConfig

    Start-AgentService -Session $Session
    Start-NodeMgrService -Session $Session
}
