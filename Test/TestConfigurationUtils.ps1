. $PSScriptRoot\Utils\PowershellTools\Invoke-UntilSucceeds.ps1
. $PSScriptRoot\Utils\PowershellTools\Invoke-NativeCommand.ps1
. $PSScriptRoot\Utils\PowershellTools\Invoke-CommandWithFunctions.ps1
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

function New-HnsTransparentNetwork
{
    Param (
        [Parameter(Mandatory = $true)] [String] $Name,
        [Parameter(Mandatory = $true)] [String] $NetworkAdapterName
    )

    $NetObj = @{
        Type = 'Transparent'
        Name = $Name
        NetworkAdapterName = $NetworkAdapterName
    }

    $Request = ConvertTo-Json $NetObj -Depth 10
    $Response = ""

    $Signature = @'
[DllImport("vmcompute.dll")]
public static extern void HNSCall([MarshalAs(UnmanagedType.LPWStr)] string method, [MarshalAs(UnmanagedType.LPWStr)] string path, [MarshalAs(UnmanagedType.LPWStr)] string request, [MarshalAs(UnmanagedType.LPWStr)] out string response);
'@
    $HnsApi = Add-Type -MemberDefinition $Signature -Namespace WindowsCI.VmCompute -Name NativeMethods -PassThru
    $HnsApi::HNSCall('POST', '/networks', "$Request", [ref] $Response)
    if ($Response)
    {
        $Output = ($Response | ConvertFrom-Json)
        if ($Output.PSobject.Properties.Name -contains 'Error') {
             throw $Output
        }
        $Output = $Output.Output
    }

    return $Output
}

function Enable-VRouterExtension {
    Param (
        [Parameter(Mandatory = $true)] [Testbed] $Testbed,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig,
        [Parameter(Mandatory = $false)] [string] $ContainerNetworkName = "ContrailRootNetwork"
    )

    Write-Log "Enabling Extension"

    Wait-RemoteInterfaceIP -Session $Testbed.GetSession() -AdapterName $Testbed.DataAdapterName

    Invoke-CommandWithFunctions -Functions "New-HnsTransparentNetwork" -Session $Testbed.GetSession() {
        New-HnsTransparentNetwork -NetworkAdapterName $Using:Testbed.DataAdapterName -Name $Using:ContainerNetworkName | Out-Null
    }

    # We're not waiting for IP on this adapter, because our tests
    # don't rely on this adapter to have the correct IP set for correctess.
    # We could implement retrying to avoid flakiness but it's easier to just
    # ignore the error.
    # Wait-RemoteInterfaceIP -Session $Testbed.GetSession() -AdapterName $Testbed.VHostName

    Invoke-Command -Session $Testbed.GetSession() -ScriptBlock {
        $Extension = Get-VMSwitch | Get-VMSwitchExtension -Name $Using:SystemConfig.ForwardingExtensionName | Where-Object Enabled
        if ($Extension) {
            Write-Warning "Extension already enabled on: $($Extension.SwitchName)"
        }
        $Extension = Enable-VMSwitchExtension -VMSwitchName $Using:Testbed.VmSwitchName -Name $Using:SystemConfig.ForwardingExtensionName
        if ((-not $Extension.Enabled) -or (-not ($Extension.Running))) {
            throw "Failed to enable extension (not enabled or not running)"
        }
    }
}

function Disable-VRouterExtension {
    Param (
        [Parameter(Mandatory = $true)] [Testbed] $Testbed,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    Write-Log "Disabling Extension"

    Invoke-Command -Session $Testbed.GetSession() -ScriptBlock {
        Disable-VMSwitchExtension -VMSwitchName $Using:Testbed.VmSwitchName -Name $Using:SystemConfig.ForwardingExtensionName -ErrorAction SilentlyContinue | Out-Null
        if (Get-Command -Name Get-ContainerNetwork -ErrorAction SilentlyContinue) {
            Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $Using:Testbed.DataAdapterName | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
            Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $Using:Testbed.DataAdapterName | Remove-ContainerNetwork -Force
        }
        elseif (Get-Command -Name Get-HnsNetwork -ErrorAction SilentlyContinue) {
            Get-HnsNetwork | Where-Object NetworkAdapterName -eq $Using:Testbed.DataAdapterName | Remove-HnsNetwork
        }
        else {
            throw 'Either Get/Remove-ContainerNetwork or Get/Remove-HnsNetwork cmdlets need to be avaliable.'
        }
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
        [Parameter(Mandatory = $true)] [Testbed] $Testbed
    )

    Write-Log "Checking if VmSwitch '$($Testbed.VmSwitchName)' exists..."

    $r = Invoke-Command -Session $Testbed.GetSession() -ScriptBlock {
        Get-VMSwitch $Using:Testbed.VmSwitchName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty isDeleted
    }

    if($null -eq $r) {
        Write-Log '... it does not.'
        return $false
    }
    elseif($r.Equals($true)) {
        Write-Log '... it still exists, but is being deleted.'
        return $false
    }
    elseif($r.Equals($false)) {
        Write-Log '... it exists.'
        return $true
    }

    Write-Log "... it returned: $r"
    throw "Checking if switch exists failed."
}

function Write-IpAddresses {
    Param (
        [Parameter(Mandatory = $true)] [Testbed] $Testbed
    )

    $AdaptersNames = @($Testbed.VHostName, $Testbed.DataAdapterName)

    $Infos = Invoke-Command -Session $Testbed.GetSession() -ScriptBlock {
        $Ret = @{}
        $Using:AdaptersNames | ForEach-Object {
            $Ip = (Get-NetAdapter -Name $_ -ErrorAction SilentlyContinue | Get-NetIPAddress -ErrorAction SilentlyContinue | Where-Object AddressFamily -eq "IPv4" | Select-Object -ExpandProperty IPAddress)
            $Ret.Add($_,  $Ip)
        }
        return $Ret
    }

    foreach($Info in $Infos.GetEnumerator()) {
        Write-Log "IP on '$($Info.Key)': $($Info.Value)"
    }
}

function Assert-VmSwitchInitialized {
    Param (
        [Parameter(Mandatory = $true)] [Testbed] $Testbed
    )
    if(-not (Test-IfVmSwitchExist -Testbed $Testbed)) {
        throw "VmSwitch is not created. No need to wait for IP on $($Testbed.VHostName)."
    }

    Write-IPAddresses -Testbed $Testbed

    Wait-RemoteInterfaceIP -Session $Testbed.GetSession() -AdapterName $Testbed.VHostName
}

class RestartNeededException : System.Exception {
    RestartNeededException([string] $msg) : base($msg) {}
    RestartNeededException([string] $msg, [System.Exception] $inner) : base($msg, $inner) {}
}

function Restart-Testbed {
    Param (
        [Parameter(Mandatory = $true)] [Testbed] $Testbed,
        [Parameter(Mandatory = $true)] [ScriptBlock] $AfterRestart
    )

    Write-Log "Restarting testbed $($Testbed.GetSession().ComputerName)"

    Invoke-Command -Session $Testbed.GetSession() {
        netcfg -D
        Restart-Computer -Force
    }

    Invoke-UntilSucceeds `
        -Name "Waiting for $($Testbed.Address) to restart" `
        -Interval 10 `
        -Duration 600 `
        -ScriptBlock {
            Test-Connection -Quiet -ComputerName $Testbed.Address
        }

    $IP = $Testbed.DataIpInfo.IPAddress
    $Pref = $Testbed.DataIpInfo.PrefixLength
    $AdapterName = $Testbed.DataAdapterName

    . $AfterRestart

    Invoke-Command -Session $Testbed.GetSession() {
        Set-NetIPInterface -InterfaceAlias $Using:AdapterName -Dhcp Disabled -PolicyStore PersistentStore
        Restart-NetAdapter -InterfaceAlias $Using:AdapterName
        New-NetIPAddress -InterfaceAlias $Using:AdapterName -IPAddress $Using:IP -PrefixLength $Using:Pref
    }
}

function Assert-VmSwitchDeleted {
    Param (
        [Parameter(Mandatory = $true)] [Testbed] $Testbed,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )
    if(Test-IfVmSwitchExist -Testbed $Testbed) {
        throw "VmSwitch is not going to be deleted. No need to wait for IP on $($Testbed.DataAdapterName)."
    }

    Write-IPAddresses -Testbed $Testbed

    try {
        Wait-RemoteInterfaceIP -Session $Testbed.GetSession() -AdapterName $Testbed.DataAdapterName
    }
    catch {
        throw [RestartNeededException]::new("Restart needed.")
    }
}

# Before running this function make sure CNM-Plugin config file is created.
# It can be done by function New-CNMPluginConfigFile.
function Initialize-CnmPluginAndExtension {
    Param (
        [Parameter(Mandatory = $true)] [Testbed] $Testbed,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    Write-Log "Initializing CNMPlugin and Extension"

    $NRetries = 3;
    foreach ($i in 1..$NRetries) {
        # CNMPlugin automatically enables Extension
        Start-CNMPluginService -Session $Testbed.GetSession()

        try {
            $Sess = $Testbed.GetSession()

            Invoke-UntilSucceeds -Name 'IsCNMPluginServiceRunning' -Duration 15 {
                Test-IsCNMPluginServiceRunning -Session $Sess
            }

            Invoke-UntilSucceeds -Name 'IsCnmPluginEnabled' -Duration 600 -Interval 5 {
                Assert-CnmPluginEnabled -Session $Sess
            }

            Assert-VmSwitchInitialized -Testbed $Testbed

            break
        }
        catch {
            Write-Log "CNM plugin was not enabled. Exception: $_"
            Write-Log "Trying to revert CNM Plugin initialization."

            Remove-CnmPluginAndExtension -Testbed $Testbed -SystemConfig $SystemConfig

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
        [Parameter(Mandatory = $true)] [Testbed] $Testbed,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    Write-Log "Stopping CNMPlugin and disabling Extension"

    Stop-CNMPluginService -Session $Testbed.GetSession()
    Disable-VRouterExtension -Testbed $Testbed -SystemConfig $SystemConfig

    try {
        Assert-VmSwitchDeleted -Testbed $Testbed -SystemConfig $SystemConfig
    }
    catch [RestartNeededException] {
        Write-Log "Error while removing vSwitch."

        Restart-Testbed -Testbed $Testbed -AfterRestart {
            Stop-CNMPluginService -Session $Testbed.GetSession()
        }
    }
}

function Clear-TestConfiguration {
    Param ([Parameter(Mandatory = $true)] [Testbed] $Testbed,
           [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig)

    Write-Log "Cleaning up test configuration"

    Write-Log "Agent service status: $(Get-ServiceStatus -Session $Testbed.GetSession() -ServiceName $(Get-AgentServiceName))"
    Write-Log "CNMPlugin service status: $(Get-ServiceStatus -Session $Testbed.GetSession() -ServiceName $(Get-CNMPluginServiceName))"
    Write-Log "NodeManager service status: $(Get-ServiceStatus -Session $Testbed.GetSession() -ServiceName $(Get-NodeMgrServiceName))"

    Remove-AllUnusedDockerNetworks -Session $Testbed.GetSession()
    Stop-NodeMgrService -Session $Testbed.GetSession()
    Stop-CNMPluginService -Session $Testbed.GetSession()
    Stop-AgentService -Session $Testbed.GetSession()
    Disable-VRouterExtension -Testbed $Testbed -SystemConfig $SystemConfig

    try {
        Assert-VmSwitchDeleted -Testbed $Testbed -SystemConfig $SystemConfig
    }
    catch [RestartNeededException] {
        Write-Log "Error while removing vSwitch."

        Restart-Testbed -Testbed $Testbed -AfterRestart {
            Stop-NodeMgrService -Session $Testbed.GetSession()
            Stop-CNMPluginService -Session $Testbed.GetSession()
            Stop-AgentService -Session $Testbed.GetSession()
        }
    }
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
