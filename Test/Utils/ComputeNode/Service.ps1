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
        throw [HardError]::new("Unknown (wild) error appeared while creating $ServiceName service")
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

    Write-Log $Output
}

function Enable-Service {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName
    )

    Invoke-Command -Session $Session -ScriptBlock {
        Start-Service $using:ServiceName
    } | Out-Null
}

function Disable-Service {
    Param (
        [Parameter(Mandatory=$true)] $Session,
        [Parameter(Mandatory=$true)] $ServiceName
    )

    Invoke-Command -Session $Session -ScriptBlock {
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
    #redirect stdout and stderr to the log file
    $Output = Invoke-NativeCommand -Session $Session -ScriptBlock {
        nssm set $using:ServiceName AppStdout $using:LogPath
        nssm set $using:ServiceName AppStderr $using:LogPath
    }

    Write-Log $Output
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
    Get-ServiceStatus -Session $Session -ServiceName $(Get-CNMPluginServiceName)
}

function New-CNMPluginService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )
    $LogDir = Get-ComputeLogsDir
    $LogPath = Join-Path $LogDir "contrail-cnm-plugin-service.log"

    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Force -Path $using:LogDir -ErrorAction SilentlyContinue | Out-Null
    }

    $ServiceName = Get-CNMPluginServiceName
    $ExecutablePath = Get-CNMPluginExecutablePath

    Install-ServiceWithNSSM -Session $Session `
        -ServiceName $ServiceName `
        -ExecutablePath $ExecutablePath `
        -CommandLineParams @()

    Out-StdoutAndStderrToLogFile -Session $Session `
        -ServiceName $ServiceName `
        -LogPath $LogPath
}

function Enable-CNMPluginService {
    Param (
        [Parameter(Mandatory = $true)] $Session,
        [Parameter(Mandatory = $false)] [int] $WaitTime = 10
    )
    Write-Log "Starting CNM Plugin"
    $ServiceName = Get-CNMPluginServiceName

    Invoke-Command -Session $Session -ScriptBlock {
        Start-Service $using:ServiceName
    }

    Start-Sleep -s $WaitTime
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

function Test-IsCNMPluginServiceRunning {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    return $($(Get-CNMPluginServiceStatus -Session $Session) -eq "Running")
}
