. $PSScriptRoot\..\..\..\CIScripts\Common\Init.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Invoke-CommandWithFunctions.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1

function Get-DefaultCNMPluginsConfigPath {
    return "C:\ProgramData\Contrail\etc\contrail\cnm-driver.conf"
}

function New-CNMPluginConfigFile {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [string] $AdapterName,
        [Parameter(Mandatory = $true)] [OpenStackConfig] $OpenStackConfig,
        [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig
    )
    $ConfigPath = Get-DefaultCNMPluginsConfigPath

    $Config = @"
[DRIVER]
Adapter=$AdapterName
ControllerIP=$( $ControllerConfig.Address )
ControllerPort=8082
AgentURL=http://127.0.0.1:9091
VSwitchName=Layered?<adapter>

[AUTH]
AuthMethod=$( $ControllerConfig.AuthMethod )

[KEYSTONE]
Os_auth_url=$( $OpenStackConfig.AuthUrl() )
Os_username=$( $OpenStackConfig.Username )
Os_tenant_name=$( $OpenStackConfig.Project )
Os_password=$( $OpenStackConfig.Password )
Os_token=
"@

    Invoke-Command -Session $Session -ScriptBlock {
        Set-Content -Path $Using:ConfigPath -Value $Using:Config
    }
}

function Get-DefaultNodeMgrsConfigPath {
    return "C:\ProgramData\Contrail\etc\contrail\contrail-vrouter-nodemgr.conf"
}
function New-NodeMgrConfig {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [string] $ControllerIP
    )

    $ConfigPath = Get-DefaultNodeMgrsConfigPath
    $LogPath = Join-Path (Get-ComputeLogsDir) "contrail-vrouter-nodemgr.log"

    $HostIP = Get-NodeManagementIP -Session $Session

    $Config = @"
[DEFAULTS]
log_local=1
log_level=SYS_DEBUG
log_file=$LogPath
hostip=$HostIP

[COLLECTOR]
server_list=${ControllerIP}:8086

[SANDESH]
introspect_ssl_enable=False
sandesh_ssl_enable=False
"@

    Invoke-Command -Session $Session -ScriptBlock {
        Set-Content -Path $Using:ConfigPath -Value $Using:Config
    }
}

#Function executed in the remote machine to create Agent's config file.
function Prepare-AgentConfig {
    Param (
        [Parameter(Mandatory = $true)] [string] $ControllerIP,
        [Parameter(Mandatory = $true)] [string] $VHostIfName,
        [Parameter(Mandatory = $true)] [string] $VHostIfIndex,
        [Parameter(Mandatory = $true)] [string] $PhysIfName
    )
    $VHostIP = (Get-NetIPAddress -ifIndex $VHostIfIndex -AddressFamily IPv4).IPAddress
    $PrefixLength = (Get-NetIPAddress -ifIndex $VHostIfIndex -AddressFamily IPv4).PrefixLength
    $VHostGateway = (Get-NetIPConfiguration -InterfaceIndex $VHostIfIndex).IPv4DefaultGateway
    $VHostGatewayConfig = if ($VHostGateway) { "gateway=$( $VHostGateway.NextHop )" } else { "" }

    return @"
[DEFAULT]
platform=windows

[CONTROL-NODE]
servers=$ControllerIP

[VIRTUAL-HOST-INTERFACE]
name=$VHostIfName
ip=$VHostIP/$PrefixLength
$VHostGatewayConfig
physical_interface=$PhysIfName
"@
}

function New-AgentConfig {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )
    # Gather information about testbed's network adapters
    $HNSTransparentAdapter = Get-RemoteNetAdapterInformation `
            -Session $Session `
            -AdapterName $SystemConfig.VHostName

    $PhysicalAdapter = Get-RemoteNetAdapterInformation `
            -Session $Session `
            -AdapterName $SystemConfig.AdapterName

    Invoke-CommandWithFunctions -Functions "Prepare-AgentConfig" -Session $Session -ScriptBlock {
        # Save file with prepared config
        $ConfigFileContent = Prepare-AgentConfig
            -ControllerIP $Using:ControllerConfig.Address
            -VHostIfName $Using:HNSTransparentAdapter.ifName
            -VHostIfIndex $Using:HNSTransparentAdapter.ifIndex
            -PhysIfName $Using:PhysicalAdapter.ifName

        Set-Content -Path $Using:AgentConfigFilePath -Value $ConfigFileContent
    }
}
