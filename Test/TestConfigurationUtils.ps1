. $PSScriptRoot\..\CIScripts\Common\Invoke-UntilSucceeds.ps1
. $PSScriptRoot\..\CIScripts\Common\Invoke-NativeCommand.ps1
. $PSScriptRoot\..\CIScripts\Common\Invoke-CommandWithFunctions.ps1
. $PSScriptRoot\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\..\CIScripts\Testenv\Testbed.ps1

. $PSScriptRoot\Utils\ComputeNode\Configuration.ps1
. $PSScriptRoot\Utils\ComputeNode\Service.ps1
. $PSScriptRoot\Utils\DockerImageBuild.ps1
. $PSScriptRoot\PesterLogger\PesterLogger.ps1

$AGENT_EXECUTABLE_PATH = "C:/Program Files/Juniper Networks/agent/contrail-vrouter-agent.exe"

function Stop-ProcessIfExists {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $ProcessName)

    Invoke-Command -Session $Session -ScriptBlock {
        $Proc = Get-Process $Using:ProcessName -ErrorAction SilentlyContinue
        if ($Proc) {
            $Proc | Stop-Process -Force -PassThru | Wait-Process -ErrorAction SilentlyContinue
        }
    }
}

function Test-IsProcessRunning {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $ProcessName)

    $Proc = Invoke-Command -Session $Session -ScriptBlock {
        return $(Get-Process $Using:ProcessName -ErrorAction SilentlyContinue)
    }

    return [bool] $Proc
}

function Assert-AreDLLsPresent {
    Param (
        [Parameter(Mandatory=$true)] $ExitCode
    )
    #https://msdn.microsoft.com/en-us/library/cc704588.aspx
    #Value below is taken from the link above and it indicates
    #that application failed to load some DLL.
    $MissingDLLsErrorReturnCode = [int64]0xC0000135
    $System32Dir = "C:/Windows/System32"

    if ([int64]$ExitCode -eq $MissingDLLsErrorReturnCode) {
        $VisualDLLs = @("msvcp140d.dll", "ucrtbased.dll", "vcruntime140d.dll")
        $MissingVisualDLLs = @()

        foreach($DLL in $VisualDLLs) {
            if (-not (Test-Path $(Join-Path $System32Dir $DLL))) {
                $MissingVisualDLLs += $DLL
            }
        }

        if ($MissingVisualDLLs.count -ne 0) {
            throw "$MissingVisualDLLs must be present in $System32Dir"
        }
        else {
            throw "Some other not known DLL(s) couldn't be loaded"
        }
    }
}

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

    # We're not waiting for IP on this adapter, because our tests
    # don't rely on this adapter to have the correct IP set for correctess.
    # We could implement retrying to avoid flakiness but it's easier to just
    # ignore the error.
    # Wait-RemoteInterfaceIP -Session $Session -AdapterName $SystemConfig.VHostName

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

function Disable-VRouterExtension {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    Write-Log "Disabling Extension"

    $AdapterName = $SystemConfig.AdapterName
    $ForwardingExtensionName = $SystemConfig.ForwardingExtensionName
    $VMSwitchName = $SystemConfig.VMSwitchName()

    Invoke-Command -Session $Session -ScriptBlock {
        Disable-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue | Out-Null
        Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $Using:AdapterName | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $Using:AdapterName | Remove-ContainerNetwork -Force
    }
}

function Test-IsVRouterExtensionEnabled {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    $ForwardingExtensionName = $SystemConfig.ForwardingExtensionName
    $VMSwitchName = $SystemConfig.VMSwitchName()

    $Ext = Invoke-Command -Session $Session -ScriptBlock {
        return $(Get-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue)
    }

    return $($Ext.Enabled -and $Ext.Running)
}

function Test-IsCnmPluginEnabled {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    function Test-IsCnmPluginListening {
        return Invoke-Command -Session $Session -ScriptBlock {
            return Test-Path //./pipe/Contrail
        }
    }

    function Test-IsCnmPluginRegistered {
        return Invoke-Command -Session $Session -ScriptBlock {
            return Test-Path $Env:ProgramData/docker/plugins/Contrail.spec
        }
    }

    return (Test-IsCnmPluginListening) -And `
        (Test-IsCnmPluginRegistered)
}

function Test-IfUtilsCanLoadDLLs {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session
    )
    $Utils = @(
        "vif.exe",
        "nh.exe",
        "rt.exe",
        "flow.exe"
    )
    Invoke-CommandWithFunctions `
        -Session $Session `
        -Functions "Assert-AreDLLsPresent" `
        -ScriptBlock {
            foreach ($Util in $using:Utils) {
                & $Util 2>&1 | Out-Null
                Assert-AreDLLsPresent -ExitCode $LastExitCode
            }
    }
}

function Test-IfAgentCanLoadDLLs {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session
    )
    Invoke-CommandWithFunctions `
        -Session $Session `
        -Functions "Assert-AreDLLsPresent" `
        -ScriptBlock {
            & $using:AGENT_EXECUTABLE_PATH --version 2>&1 | Out-Null
            Assert-AreDLLsPresent -ExitCode $LastExitCode
    }
}

function Read-SyslogForAgentCrash {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [DateTime] $After)
    Invoke-Command -Session $Session -ScriptBlock {
        Get-EventLog -LogName "System" -EntryType "Error" `
            -Source "Service Control Manager" `
            -Message "The contrail-vrouter-agent service terminated unexpectedly*" `
            -After ($Using:After).addSeconds(-1)
    }
}

function New-DockerNetwork {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $Name,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $false)] [string] $Network,
           [Parameter(Mandatory = $false)] [string] $Subnet)

    if (!$Network) {
        $Network = $Name
    }

    Write-Log "Creating network $Name"

    $NetworkID = Invoke-Command -Session $Session -ScriptBlock {
        if ($Using:Subnet) {
            return $(docker network create --ipam-driver windows --driver Contrail -o tenant=$Using:TenantName -o network=$Using:Network --subnet $Using:Subnet $Using:Name)
        }
        else {
            return $(docker network create --ipam-driver windows --driver Contrail -o tenant=$Using:TenantName -o network=$Using:Network $Using:Name)
        }
    }

    return $NetworkID
}

function Remove-AllUnusedDockerNetworks {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Removing all docker networks"

    Invoke-Command -Session $Session -ScriptBlock {
        docker network prune --force | Out-Null
    }
}

function Select-ValidNetIPInterface {
    Param ([parameter(Mandatory=$true, ValueFromPipeline=$true)]$GetIPAddressOutput)

    Process { $_ `
        | Where-Object AddressFamily -eq "IPv4" `
        | Where-Object { ($_.SuffixOrigin -eq "Dhcp") -or ($_.SuffixOrigin -eq "Manual") }
    }
}

function Wait-RemoteInterfaceIP {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [String] $AdapterName)

    Invoke-CommandWithFunctions -Functions @("Select-ValidNetIPInterface", "Invoke-UntilSucceeds") -Session $Session {
        $UntilSucceedsArgs = @($Using:AdapterName, $( Get-Content function:"Select-ValidNetIPInterface" ))

        Invoke-UntilSucceeds -Name "Waiting for IP on interface $Using:AdapterName" -Duration 120 -Arguments $UntilSucceedsArgs {
            Param(
                [Parameter(Mandatory = $true)] [String] $AdapterName
                [Parameter(Mandatory = $true)] [String] $SelectValidNetIPInterfaceContent
            )
            $SelectValidNetIPInterfaceSB = [ScriptBlock]::Create($SelectValidNetIPInterfaceContent)

            Get-NetAdapter -Name $AdapterName `
            | Get-NetIPAddress -ErrorAction SilentlyContinue `
            | &$SelectValidNetIPInterfaceSB
        }
    } | Out-Null
}

# Before running this function make sure CNM-Plugin config file is created.
# It can be done by function New-CNMPluginConfigFile.
function Initialize-CnmPluginAndExtension {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    Write-Log "Initializing CNMPlugin and Extension"

    $NRetries = 3;
    foreach ($i in 1..$NRetries) {
        Wait-RemoteInterfaceIP -Session $Session -AdapterName $SystemConfig.AdapterName

        # CNMPlugin automatically enables Extension
        Start-CNMPluginService -Session $Session

        try {
            $TestCNMRunning = { Test-IsCNMPluginServiceRunning -Session $Session }

            $TestCNMRunning | Invoke-UntilSucceeds -Duration 15

            {
                if (-not (Invoke-Command $TestCNMRunning)) {
                    throw [HardError]::new("CNM plugin service didn't start")
                }
                Test-IsCnmPluginEnabled -Session $Session
            } | Invoke-UntilSucceeds -Duration 600 -Interval 5

            Wait-RemoteInterfaceIP -Session $Session -AdapterName $SystemConfig.VHostName

            break
        }
        catch {
            Write-Log $_

            if ($i -eq $NRetries) {
                throw "CNM plugin was not enabled."
            } else {
                Write-Log "CNM plugin was not enabled, retrying."
                Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig
            }
        }
    }
}

function Clear-TestConfiguration {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig)

    Write-Log "Cleaning up test configuration"

    Write-Log "Agent service status: $(Get-ServiceStatus -Session $Session -ServiceName $(Get-AgentServiceName))"
    Write-Log "CNMPlugin service status: $(Get-ServiceStatus -Session $Session -ServiceName $(Get-CNMPluginServiceName))"

    Remove-AllUnusedDockerNetworks -Session $Session
    Stop-NodeMgrService -Session $Session
    Stop-CNMPluginService -Session $Session
    Stop-AgentService -Session $Session
    Disable-VRouterExtension -Session $Session -SystemConfig $SystemConfig

    Wait-RemoteInterfaceIP -Session $Session -AdapterName $SystemConfig.AdapterName
}

function Remove-DockerNetwork {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Invoke-Command -Session $Session -ScriptBlock {
        docker network rm $Using:Name | Out-Null
    }
}
