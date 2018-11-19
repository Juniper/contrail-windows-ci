. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Invoke-NativeCommand.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1
. $PSScriptRoot\Configuration.ps1

function Install-ServiceWithNSSM {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName,
        [Parameter(Mandatory=$true)] $ExecutablePath,
        [Parameter(Mandatory=$false)] [string[]] $CommandLineParams = @()
    )

    $Output = Invoke-NativeCommand -Session $Session -ScriptBlock {
            nssm install $using:ServiceName "$using:ExecutablePath" $using:CommandLineParams
    } -AllowNonZero -CaptureOutput

    $NSSMServiceAlreadyCreatedError = 5
    if ($Output.ExitCode -eq 0) {
        Write-Log $Output.Output
    }
    elseif ($Output.ExitCode -eq $NSSMServiceAlreadyCreatedError) {
        Write-Log "$ServiceName service already created, continuing..."
    }
    else {
        $ExceptionMessage = @"
Unknown (wild) error appeared while creating $ServiceName service.
ExitCode: $($Output.ExitCode)
NSSM output: $($Output.Output)
"@
        throw [HardError]::new($ExceptionMessage)
    }
}

function Remove-ServiceWithNSSM {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName
    )

    $Output = Invoke-NativeCommand -Session $Session {
        nssm remove $using:ServiceName confirm
    } -CaptureOutput

    Write-Log $Output.Output
}

function Start-RemoteService {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName
    )

    Write-Log "Starting $ServiceName"

    Invoke-Command -Session $Session -ScriptBlock {
        Start-Service $using:ServiceName
    } | Out-Null
}

function Stop-RemoteService {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName
    )

    Write-Log "Stopping $ServiceName"

    Invoke-Command -Session $Session -ScriptBlock {
        # Some tests which don't use all components, use Clear-TestConfiguration function.
        # Ignoring errors here allows us to get rid of boilerplate code, which
        # would be needed to handle cases where not all services are present on testbed(s).
        Stop-Service $using:ServiceName -ErrorAction SilentlyContinue
    } | Out-Null
}

function Get-ServiceStatus {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName
    )

    Invoke-Command -Session $Session -ScriptBlock {
        $Service = Get-Service $using:ServiceName -ErrorAction SilentlyContinue
        if ($Service -and $Service.Status) {
            return $Service.Status.ToString()
        } else {
            return $null
        }
    }
}

function Out-StdoutAndStderrToLogFile {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName,
        [Parameter(Mandatory=$true)] $LogPath
    )

    $Output = Invoke-NativeCommand -Session $Session -ScriptBlock {
        nssm set $using:ServiceName AppStdout $using:LogPath
        nssm set $using:ServiceName AppStderr $using:LogPath
    } -CaptureOutput

    Write-Log $Output.Output
}

function Get-AgentServiceConfiguration {
    $LogDir = Get-ComputeLogsDir
    $LogPath = Join-Path $LogDir "contrail-vrouter-agent-service.log"

    $ExecutablePath = "C:\Program Files\Juniper Networks\agent\contrail-vrouter-agent.exe"
    $ServiceName = "contrail-vrouter-agent"

    $ConfigPath = Get-DefaultAgentConfigPath
    $ConfigFileParam = "--config_file=$ConfigPath"

    return @{
        "ServiceName" = $ServiceName;
        "ExecutablePath" = $ExecutablePath;
        "LogPath" = $LogPath;
        "CommandLineParams" = @($ConfigFileParam);
    }
}

function Get-CNMPluginServiceConfiguration {
    $LogDir = Get-ComputeLogsDir
    $LogPath = Join-Path $LogDir "contrail-cnm-plugin-service.log"

    $ExecutablePath = "C:\Program Files\Juniper Networks\cnm-plugin\contrail-cnm-plugin.exe"
    $ServiceName = "contrail-cnm-plugin"

    return @{
        "ServiceName" = $ServiceName;
        "ExecutablePath" = $ExecutablePath;
        "LogPath" = $LogPath;
        "CommandLineParams" = @();
    }
}

function Get-NodeMgrServiceConfiguration {
    $LogDir = Get-ComputeLogsDir
    $LogPath = Join-Path $LogDir "contrail-vrouter-nodemgr-service.log"

    $ExecutablePath = "C:\Python27\Scripts\contrail-nodemgr.exe"
    $ServiceName = "contrail-vrouter-nodemgr"

    $NodeTypeParam = "--nodetype contrail-vrouter"

    return @{
        "ServiceName" = $ServiceName;
        "ExecutablePath" = $ExecutablePath;
        "LogPath" = $LogPath;
        "CommandLineParams" = @($NodeTypeParam);
    }
}

function Get-ServiceName {
    Param (
        [Parameter(Mandatory = $true)] [PSCustomObject] $Configuration
    )

    return $Configuration.GetEnumerator() | Where-Object { $_.Key -eq "ServiceName" }
}

function Get-AgentServiceName {
    return Get-ServiceName -Configuration $(Get-AgentServiceConfiguration)
}

function Get-CNMPluginServiceName {
    return Get-ServiceName -Configuration $(Get-CNMPluginServiceConfiguration)
}

function Get-NodeMgrServiceName {
    return Get-ServiceName -Configuration $(Get-NodeMgrServiceConfiguration)
}

function Test-IsCNMPluginServiceRunning {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    $ServiceName = Get-CNMPluginServiceName
    return $((Get-ServiceStatus -ServiceName $ServiceName -Session $Session) -eq "Running")
}

function New-RemoteService {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName,
        [Parameter(Mandatory=$true)] $ExecutablePath,
        [Parameter(Mandatory=$true)] $LogPath,
        [Parameter(Mandatory=$true)] [string[]] $CommandLineParams
    )

    Install-ServiceWithNSSM `
        -Session $Session `
        -ServiceName $ServiceName `
        -ExecutablePath $ExecutablePath `
        -CommandLineParams $CommandLineParams

    Out-StdoutAndStderrToLogFile `
        -Session $Session `
        -ServiceName $ServiceName `
        -LogPath $LogPath
}

function New-AgentService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    $Conf = Get-AgentServiceConfiguration

    New-RemoteService `
        -Session $Session `
        @Conf
}

function New-CNMPluginService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    $Conf = Get-CNMPluginServiceConfiguration

    New-RemoteService `
        -Session $Session `
        @Conf
}

function New-NodeMgrService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    $Conf = Get-NodeMgrServiceConfiguration

    New-RemoteService `
        -Session $Session `
        @Conf
}

function Start-AgentService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    Start-RemoteService -Session $Session -ServiceName $(Get-AgentServiceName)
}

function Start-CNMPluginService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    Start-RemoteService -Session $Session -ServiceName $(Get-CNMPluginServiceName)
}

function Start-NodeMgrService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    Start-RemoteService -Session $Session -ServiceName $(Get-NodeMgrServiceName)
}


function Stop-CNMPluginService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    $ServiceName = Get-CNMPluginServiceName

    Stop-RemoteService -Session $Session -ServiceName $ServiceName

    Invoke-Command -Session $Session -ScriptBlock {
        Stop-Service docker | Out-Null

        # Removing NAT objects when 'winnat' service is stopped may fail.
        # In this case, we have to try removing all objects but ignore failures for some of them.
        Get-NetNat | ForEach-Object {
            Remove-NetNat $_.Name -Confirm:$false -ErrorAction SilentlyContinue
        }

        # Removing ContainerNetworks may fail for NAT network when 'winnat'
        # service is disabled, so we have to filter out all NAT networks.
        Get-ContainerNetwork | Where-Object Name -NE nat | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        # Workaround for flaky HNS behavior.
        # Removing container networks sometimes ends with "Unspecified error".
        Get-ContainerNetwork | Where-Object Name -NE nat | Remove-ContainerNetwork -Force

        Start-Service docker | Out-Null
    }
}

function Stop-AgentService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    Stop-RemoteService -Session $Session -ServiceName (Get-AgentServiceName)
}

function Stop-NodeMgrService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    Stop-RemoteService -Session $Session -ServiceName (Get-NodeMgrServiceName)
}

function Remove-CNMPluginService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    $ServiceName = Get-CNMPluginServiceName
    $ServiceStatus = Get-CNMPluginServiceStatus -Session $Session

    if ($ServiceStatus -ne "Stopped") {
        Stop-CNMPluginService -Session $Session
    }

    Remove-ServiceWithNSSM -Session $Session -ServiceName $ServiceName
}

function Remove-AgentService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    $ServiceName = Get-AgentServiceName
    $ServiceStatus = Get-ServiceStatus -Session $Session -ServiceName $ServiceName

    if ($ServiceStatus -ne "Stopped") {
        Stop-AgentService -Session $Session
    }

    Remove-ServiceWithNSSM -Session $Session -ServiceName $ServiceName
}

function Remove-NodeMgrService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )

    $ServiceName = Get-NodeMgrServiceName
    $ServiceStatus = Get-ServiceStatus -Session $Session -ServiceName $ServiceName

    if ($ServiceStatus -ne "Stopped") {
        Stop-NodeMgrService -Session $Session
    }

    Remove-ServiceWithNSSM -Session $Session -ServiceName $ServiceName
}
