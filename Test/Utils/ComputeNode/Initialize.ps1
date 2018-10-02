. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\DockerNetwork\DockerNetwork.ps1

function Enable-VRouterExtension {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig,
        [Parameter(Mandatory = $false)] [string] $ContainerNetworkName = "testnet"
    )

    Write-Log "Enabling Extension"

    $AdapterName = $SystemConfig.AdapterName
    $ForwardingExtensionName = $SystemConfig.ForwardingExtensionName
    $VMSwitchName = $SystemConfig.VMSwitchName()

    Wait-RemoteInterfaceIP -Session $Session -AdapterName $SystemConfig.AdapterName

    Invoke-Command -Session $Session -ScriptBlock {
        New-ContainerNetwork -Mode Transparent -NetworkAdapterName $Using:AdapterName -Name $Using:ContainerNetworkName | Out-Null
    }

    Invoke-Command -Session $Session -ScriptBlock {
        $Extension = Get-VMSwitch | Get-VMSwitchExtension -Name $Using:ForwardingExtensionName | Where-Object Enabled
        if ($Extension) {
            Write-Warning "Extension already enabled on: $($Extension.SwitchName)"
        }
        $Extension = Enable-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName
        if ((-not $Extension.Enabled) -or (-not ($Extension.Running))) {
            throw "Failed to enable extension (not enabled or not running)"
        }
    }
}

function Start-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $false)] [int] $WaitTime = 60)
    Write-Log "Starting Docker Driver"

    # We have to specify some file, because docker driver doesn't
    # currently support stderr-only logging.
    # TODO: Remove this when after "no log file" option is supported.
    $OldLogPath = "NUL"
    $LogDir = Get-ComputeLogsDir
    $DefaultConfigFilePath = Get-DefaultCNMPluginsConfigPath

    # TODO: delete the "config" argument
    # when default path for the config file is supported.
    $Arguments = @(
        "-logPath", $OldLogPath,
        "-logLevel", "Debug",
        "-config", $DefaultConfigFilePath
    )

    Invoke-Command -Session $Session -ScriptBlock {

        # Nested ScriptBlock variable passing workaround
        $Arguments = $Using:Arguments
        $LogDir = $Using:LogDir

        Start-Job -ScriptBlock {
            Param($Arguments, $LogDir)

            New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
            $LogPath = Join-Path $LogDir "contrail-windows-docker-driver.log"
            $ErrorActionPreference = "Continue"

            # "Out-File -Append" in contrary to "Add-Content" doesn't require a read lock, so logs can
            # be read while the process is running
            & "C:\Program Files\Juniper Networks\contrail-windows-docker.exe" $Arguments 2>&1 |
                Out-File -Append -FilePath $LogPath
        } -ArgumentList $Arguments, $LogDir
    }

    Start-Sleep -s $WaitTime
}

function Initialize-DriverAndExtension {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    Write-Log "Initializing Test Configuration"

    $NRetries = 3;
    foreach ($i in 1..$NRetries) {
        Wait-RemoteInterfaceIP -Session $Session -AdapterName $SystemConfig.AdapterName

        # DockerDriver automatically enables Extension
        Start-DockerDriver -Session $Session `
            -WaitTime 0

        try {
            $TestProcessRunning = { Test-IsDockerDriverProcessRunning -Session $Session }

            $TestProcessRunning | Invoke-UntilSucceeds -Duration 15

            {
                if (-not (Invoke-Command $TestProcessRunning)) {
                    throw [HardError]::new("docker process has stopped running")
                }
                Test-IsDockerDriverEnabled -Session $Session
            } | Invoke-UntilSucceeds -Duration 600 -Interval 5

            Wait-RemoteInterfaceIP -Session $Session -AdapterName $SystemConfig.VHostName

            break
        }
        catch {
            Write-Log $_

            if ($i -eq $NRetries) {
                throw "Docker driver was not enabled."
            } else {
                Write-Log "Docker driver was not enabled, retrying."
                Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig
            }
        }
    }
}

function Enable-AgentService {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Starting Agent"
    Invoke-Command -Session $Session -ScriptBlock {
        Start-Service ContrailAgent | Out-Null
    }
}

function Initialize-ComputeServices {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig,
        [Parameter(Mandatory = $true)] [OpenStackConfig] $OpenStackConfig,
        [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig
    )
    New-CNMPluginConfigFile -Session $Session `
        -AdapterName $SystemConfig.AdapterName `
        -OpenStackConfig $OpenStackConfig `
        -ControllerConfig $ControllerConfig

    Initialize-DriverAndExtension -Session $Session `
        -SystemConfig $SystemConfig

    New-AgentConfigFile -Session $Session `
        -ControllerConfig $ControllerConfig `
        -SystemConfig $SystemConfig

    Enable-AgentService -Session $Session
}

function Initialize-ComputeNode {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [TestenvConfigs] $Configs,
        [Parameter(Mandatory=$true)] [Network[]] $Networks
    )

    Initialize-ComputeServices -Session $Session `
        -SystemConfig $Configs.System `
        -OpenStackConfig $Configs.OpenStack `
        -ControllerConfig $Configs.Controller

    foreach ($Network in $Networks) {
        $ID = New-DockerNetwork -Session $Session `
            -TenantName $Configs.Controller.DefaultProject `
            -Name $Network.Name `
            -Subnet "$( $Network.Subnet.IpPrefix )/$( $Network.Subnet.IpPrefixLen )"

        Write-Log "Created network id: $ID"
    }
}
