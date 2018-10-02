. $PSScriptRoot\..\..\..\CIScripts\Common\Invoke-NativeCommand.ps1

function Install-ServiceWithNSSM {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName,
        [Parameter(Mandatory=$true)] $ExecutablePath,
        [Parameter(Mandatory=$false)] [string[]] $CommandLineParams = @()
    )
    Invoke-NativeCommand -Session $Session {
        nssm install $using:ServiceName "$using:ExecutablePath" $using:CommandLineParams
    }
}

function Remove-ServiceWithNSSM {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName
    )

    Invoke-NativeCommand -Session $Session {
        nssm remove $using:ServiceName confirm
    }
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

function Get-CNMPluginServiceName {
    return "contrail-cnm-plugin"
}

function Get-CNMPluginExecutablePath {
    return "C:\Program Files\Juniper Networks\contrail-windows-docker.exe"
}

function Get-CNMPluginServiceStatus {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )
    Get-ServiceStatus -Session $Session -ServiceName Get-CNMPluginServiceName
}

function New-CNMPluginService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )
    # We have to specify some file, because docker driver doesn't
    # currently support stderr-only logging.
    # TODO: Remove this when after "no log file" option is supported.
    $OldLogPath = "NUL"
    $LogDir = Get-ComputeLogsDir
    $LogPath = Join-Path $LogDir "contrail-windows-docker-driver.log"
    $DefaultConfigFilePath = Get-DefaultCNMPluginsConfigPath

    # TODO: delete the "config" argument
    # when default path for the config file is supported.
    $Params = @(
        "-logPath", $OldLogPath,
        "-logLevel", "Debug",
        "-config", $DefaultConfigFilePath
    )

    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Force -Path $using:LogDir | Out-Null
    }

    $ServiceName = Get-CNMPluginServiceName
    $ExecutablePath = Get-CNMPluginExecutablePath

    Install-ServiceWithNSSM -Session $Session `
        -ServiceName $ServiceName `
        -ExecutablePath $ExecutablePath `
        -CommandLineParams $Params

    #redirect stdout and stderr to the log file
    Invoke-NativeCommand -Session $Session -ScriptBlock {
        nssm set $using:ServiceName AppStdout $using:LogPath
        nssm set $using:ServiceName AppStderr $using:LogPath
    }
}

function Enable-CNMPluginService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )
    Write-Log "Starting CNM Plugin"
    $ServiceName = Get-CNMPluginServiceName

    Invoke-Command -Session $Session -ScriptBlock {
        Start-Service $using:ServiceName
    }
}

function Disable-CNMPluginService {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session
    )
    Write-Log "Stopping CNM Plugin"
    $ServiceName = Get-CNMPluginServiceName

    Invoke-Command -Session $Session -ScriptBlock {
        Stop-Service $using:ServiceName
        Stop-Service docker | Out-Null

        # Removing NAT objects when 'winnat' service is stopped may fail.
        # In this case, we have to try removing all objects but ignore failures for some of them.
        Get-NetNat | ForEach-Object {
            Remove-NetNat $_.Name -Confirm:$false -ErrorAction SilentlyContinue
        }

        # Removing ContainerNetworks may fail for NAT network when 'winnat'
        # service is disabled, so we have to filter out all NAT networks.
        Get-ContainerNetwork | Where-Object Name -NE nat | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        Get-ContainerNetwork | Where-Object Name -NE nat | Remove-ContainerNetwork -Force

        Start-Service docker | Out-Null
    }
}

function Remove-CNMPluginService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )
    $ServiceName = Get-CNMPluginServiceName
    $ServiceStatus = Get-ServiceStatus -Session $Session -ServiceName $ServiceName

    if ($ServiceStatus -ne "Stopped") {
        Disable-CNMPluginService -Session $Session
    }

    Remove-ServiceWithNSSM -Session $Session -ServiceName $ServiceName
}
