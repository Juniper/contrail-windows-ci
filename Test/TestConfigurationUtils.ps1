. $PSScriptRoot\..\CIScripts\Common\Invoke-UntilSucceeds.ps1
. $PSScriptRoot\..\CIScripts\Common\Invoke-NativeCommand.ps1
. $PSScriptRoot\..\CIScripts\Common\Invoke-CommandWithFunctions.ps1
. $PSScriptRoot\Utils\Testenv\Configs.ps1

. $PSScriptRoot\Utils\ComputeNode\Configuration.ps1
. $PSScriptRoot\Utils\ComputeNode\Service.ps1
. $PSScriptRoot\Utils\DockerImageBuild.ps1
. $PSScriptRoot\PesterLogger\PesterLogger.ps1

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

        if (0 -ne $MissingVisualDLLs.count) {
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

function Assert-CnmPluginEnabled {
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

    $PipeOpened = Test-IsCnmPluginListening
    $Registered = Test-IsCnmPluginRegistered

    if($PipeOpened -and $Registered) {
        return $true
    }
    else {
        throw "CnmPlugin not enabled. PipeOpened: $PipeOpened, Registered in Docker: $Registered"
    }
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

    Write-Log "Removing unused docker networks"

    Invoke-Command -Session $Session -ScriptBlock {
        docker network prune --force | Out-Null
    }
}

function Select-ValidNetIPInterface {
    Param ([parameter(Mandatory=$true, ValueFromPipeline=$true)]$GetIPAddressOutput)

    Process { $_ `
        | Where-Object AddressFamily -eq "IPv4" `
        | Where-Object { ("Dhcp" -eq $_.SuffixOrigin) -or ("Manual" -eq $_.SuffixOrigin) }
    }
}

function Wait-RemoteInterfaceIP {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [String] $AdapterName
    )

    Invoke-UntilSucceeds -Name "Waiting for IP on interface $AdapterName" -Duration 60 {
        Invoke-CommandWithFunctions -Functions "Select-ValidNetIPInterface" -Session $Session {
            Get-NetAdapter -Name $Using:AdapterName `
            | Get-NetIPAddress -ErrorAction SilentlyContinue `
            | Select-ValidNetIPInterface
        }
    } | Out-Null
}

function Test-IfVmSwitchExist {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [String] $VmSwitchName
    )

    $r = Invoke-Command -Session $Session -ScriptBlock {
        Get-VMSwitch $Using:VMSwitchName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty isDeleted
    }

    if(($null -eq $r) -or ($r.Equals($true))) {
        return $false
    }

     return $true
}

function Assert-VmSwitchInitialized {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )
    if(-not (Test-IfVmSwitchExist -Session $Session -VmSwitchName $SystemConfig.VMSwitchName())) {
        throw "VmSwitch is not created. No need to wait for IP on $($SystemConfig.VHostName)."
    }

    Wait-RemoteInterfaceIP -Session $Session -AdapterName $SystemConfig.VHostName
}

function Assert-VmSwitchDeleted {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )
    if(Test-IfVmSwitchExist -Session $Session -VmSwitchName $SystemConfig.VMSwitchName()) {
        throw "VmSwitch is not going to be deleted. No need to wait for IP on $($SystemConfig.AdapterName)."
    }

    Wait-RemoteInterfaceIP -Session $Session -AdapterName $SystemConfig.AdapterName
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
        # CNMPlugin automatically enables Extension
        Start-CNMPluginService -Session $Session

        try {
            Invoke-UntilSucceeds -Name 'IsCNMPluginServiceRunning' -Duration 15 {
                Test-IsCNMPluginServiceRunning -Session $Session
            }

            Invoke-UntilSucceeds -Name 'IsCnmPluginEnabled' -Duration 600 -Interval 5 {
                Assert-CnmPluginEnabled -Session $Session
            }

            Assert-VmSwitchInitialized -Session $Session -SystemConfig $SystemConfig

            break
        }
        catch {
            Write-Log "CNM plugin was not enabled. Exception: $_"
            Write-Log "Trying to revert CNM Plugin initialization."

            Remove-CnmPluginAndExtension -Session $Session -SystemConfig $SystemConfig

            if ($i -eq $NRetries) {
                throw "CNM plugin was not enabled."
            } else {
                Write-Log "Retrying CNM Plugin initialization."
            }
        }
    }
}

function Remove-CnmPluginAndExtension {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    Write-Log "Stopping CNMPlugin and disabling Extension"

    Stop-CNMPluginService -Session $Session
    Disable-VRouterExtension -Session $Session -SystemConfig $SystemConfig

    Assert-VmSwitchDeleted -Session $Session -SystemConfig $SystemConfig
}

function Clear-TestConfiguration {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig)

    Write-Log "Cleaning up test configuration"

    Write-Log "Agent service status: $(Get-ServiceStatus -Session $Session -ServiceName $(Get-AgentServiceName))"
    Write-Log "CNMPlugin service status: $(Get-ServiceStatus -Session $Session -ServiceName $(Get-CNMPluginServiceName))"
    Write-Log "NodeManager service status: $(Get-ServiceStatus -Session $Session -ServiceName $(Get-NodeMgrServiceName))"

    Remove-AllUnusedDockerNetworks -Session $Session
    Stop-NodeMgrService -Session $Session
    Stop-CNMPluginService -Session $Session
    Stop-AgentService -Session $Session
    Disable-VRouterExtension -Session $Session -SystemConfig $SystemConfig

    Assert-VmSwitchDeleted -Session $Session -SystemConfig $SystemConfig
}

function Remove-DockerNetwork {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Write-Log "Removing docker network '$Name' from '$($Session.ComputerName)'"
    Invoke-Command -Session $Session -ScriptBlock {
        docker network rm $Using:Name | Out-Null
    }
}
