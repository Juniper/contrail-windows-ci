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

function Get-AgentServiceName {
    return "contrail-vrouter-agent"
}

function Get-AgentExecutablePath {
    return "C:\Program Files\Juniper Networks\agent\contrail-vrouter-agent.exe"
}

function Get-AgentServiceStatus {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Get-ServiceStatus -Session $Session -ServiceName (Get-AgentServiceName)
}

function New-AgentService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )
    $LogDir = Get-ComputeLogsDir
    $LogPath = Join-Path $LogDir "contrail-vrouter-agent-service.log"
    $ServiceName = Get-AgentServiceName
    $ExecutablePath = Get-AgentExecutablePath

    $ConfigPath = Get-DefaultAgentConfigPath
    $ConfigFileParam = "--config_file=$ConfigPath"

    Install-ServiceWithNSSM -Session $Session `
        -ServiceName $ServiceName `
        -ExecutablePath $ExecutablePath `
        -CommandLineParams @($ConfigFileParam)

    Out-StdoutAndStderrToLogFile -Session $Session `
        -ServiceName $ServiceName `
        -LogPath $LogPath
}

function Enable-AgentService {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)
    Write-Log "Starting Agent"

    $AgentServiceName = Get-AgentServiceName
    $Output = Invoke-NativeCommand -Session $Session -ScriptBlock {
        $Output = netstat -abq  #dial tcp bug debug output
        #TODO: After the bugfix, use Enable-Service generic function here.
        Start-Service $using:AgentServiceName
        return $Output
    } -CaptureOutput
    Write-Log $Output.Output
}

function Disable-AgentService {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Stopping Agent"
    Disable-Service -Session $Session -ServiceName (Get-AgentServiceName)
}

function Remove-AgentService {
    Param (
        [Parameter(Mandatory=$true)] $Session
    )
    $ServiceName = Get-AgentServiceName
    $ServiceStatus = Get-ServiceStatus -Session $Session -ServiceName $ServiceName
    if ($ServiceStatus -ne "Stopped") {
        Disable-AgentService -Session $Session
    }
    Remove-ServiceWithNSSM -Session $Session -ServiceName $ServiceName
}
