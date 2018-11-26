. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Invoke-NativeCommand.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\Configuration.ps1
. $PSScriptRoot\Service.ps1

function Invoke-MsiExec {
    Param (
        [Switch] $Uninstall,
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [String] $Path
    )

    $Action = if ($Uninstall) { "/x" } else { "/i" }

    Invoke-Command -Session $Session -ScriptBlock {
        # Get rid of all leftover handles to the Service objects
        [System.GC]::Collect()

        $Result = Start-Process msiexec.exe -ArgumentList @($Using:Action, $Using:Path, "/quiet") `
            -Wait -PassThru

        # Do not fail while uninstaling MSIs that are not currently installed
        $MsiErrorUnknownProduct = 1605
        if ($Using:Uninstall -and ($Result.ExitCode -eq $MsiErrorUnknownProduct)) {
            return
        }

        if ($Result.ExitCode -ne 0) {
            $WhatWentWrong = if ($Using:Uninstall) {"Uninstallation"} else {"Installation"}
            throw "$WhatWentWrong of $Using:Path failed with $($Result.ExitCode)"
        }

        # Refresh Path
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    }
}

function Install-Agent {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Installing Agent"
    Invoke-MsiExec -Session $Session -Path "C:\Artifacts\contrail-vrouter-agent.msi"

    #TODO: remove this if conditional after msi do not anymore create agent's service
    $ServiceStatus = Get-ServiceStatus -Session $Session -ServiceName "ContrailAgent"

    $IsOldAgentServicePresent = ($ServiceStatus -eq "Running") -or ($ServiceStatus -eq "Started")
    if ($IsOldAgentServicePresent) {
        Stop-RemoteService -Session $Session -ServiceName "ContrailAgent"
    }
    New-AgentService -Session $Session
}

function Uninstall-Agent {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Uninstalling Agent"

    Remove-AgentService -Session $Session
    Invoke-MsiExec -Uninstall -Session $Session -Path "C:\Artifacts\contrail-vrouter-agent.msi"
}

function Install-Extension {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Installing vRouter Forwarding Extension"
    Invoke-MsiExec -Session $Session -Path "C:\Artifacts\vRouter.msi"
}

function Uninstall-Extension {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Uninstalling vRouter Forwarding Extension"
    Invoke-MsiExec -Uninstall -Session $Session -Path "C:\Artifacts\vRouter.msi"
}

function Install-Utils {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Installing vRouter utility tools"
    Invoke-MsiExec -Session $Session -Path "C:\Artifacts\utils.msi"
}

function Uninstall-Utils {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Uninstalling vRouter utility tools"
    Invoke-MsiExec -Uninstall -Session $Session -Path "C:\Artifacts\utils.msi"
}

function Install-CnmPlugin {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Installing CNM Plugin"
    Invoke-MsiExec -Session $Session -Path "C:\Artifacts\contrail-cnm-plugin.msi"
    New-CNMPluginService -Session $Session
}

function Uninstall-CnmPlugin {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Uninstalling CNM plugin"

    Remove-CNMPluginService -Session $Session
    Invoke-MsiExec -Uninstall -Session $Session -Path "C:\Artifacts\contrail-cnm-plugin.msi"
}

function Install-Nodemgr {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Installing Nodemgr"
    $Res = Invoke-NativeCommand -Session $Session -AllowNonZero -CaptureOutput -ScriptBlock {
        Get-ChildItem "C:\Artifacts\nodemgr\*.tar.gz" -Name
    }
    $Archives = $Res.Output
    foreach($A in $Archives) {
        Write-Log "- (Nodemgr) Installing pip archive $A"
        Invoke-NativeCommand -Session $Session -ScriptBlock {
            pip install "C:\Artifacts\nodemgr\$Using:A"
        } | Out-Null
    }

    New-NodeMgrService -Session $Session
}

function Uninstall-Nodemgr {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Uninstalling Nodemgr"

    Remove-NodeMgrService -Session $Session

    $Res = Invoke-NativeCommand -Session $Session -AllowNonZero -CaptureOutput -ScriptBlock {
        Get-ChildItem "C:\Artifacts\nodemgr\*.tar.gz" -Name
    }
    $Archives = $Res.Output
    foreach($P in $Archives) {
        Write-Log "- (Nodemgr) Uninstalling pip package $P"
        Invoke-NativeCommand -Session $Session -ScriptBlock {
            pip uninstall "C:\Artifacts\nodemgr\$Using:P"
        }
    }
}

function Install-Components {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $false)] [Switch] $InstallNodeMgr,
           [Parameter(Mandatory = $false)] [String] $ControllerIP)

    Install-Extension -Session $Session
    Install-CnmPlugin -Session $Session
    Install-Agent -Session $Session
    Install-Utils -Session $Session

    if ($InstallNodeMgr -and $ControllerIP) {
        Install-Nodemgr -Session $Session
        New-NodeMgrConfigFile -Session $Session -ControllerIP $ControllerIP
    }
}

function Uninstall-Components {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $false)] [Switch] $UninstallNodeMgr)

    if ($UninstallNodeMgr) {
        Uninstall-Nodemgr -Session $Session
    }

    Uninstall-Utils -Session $Session
    Uninstall-Agent -Session $Session
    Uninstall-CnmPlugin -Session $Session
    Uninstall-Extension -Session $Session
}
