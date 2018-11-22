. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\ComputeNode\Installation.ps1

# Import order is chosen explicitly because of class dependency
. $PSScriptRoot\..\ContrailNetworkManager.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\MultiNode.ps1

function Set-ConfAndLogDir {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )
    $ConfigDirPath = Get-DefaultConfigDir
    $LogDirPath = Get-ComputeLogsDir

    foreach($Session in $Sessions) {
        Invoke-Command -Session $Session -ScriptBlock {
            New-Item -ItemType Directory -Path $using:ConfigDirPath -Force | Out-Null
            New-Item -ItemType Directory -Path $using:LogDirPath -Force | Out-Null
        } | Out-Null
    }
}

function New-MultiNodeSetup {
    Param (
        [Parameter(Mandatory=$true)] [string] $TestenvConfFile,
        [Parameter(Mandatory=$false)] [Switch] $InstallNodeMgr
    )

    $VMs = Read-TestbedsConfig -Path $TestenvConfFile
    $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
    $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
    $SystemConfig = Read-SystemConfig -Path $TestenvConfFile

    $Sessions = New-RemoteSessions -VMs $VMs

    Set-ConfAndLogDir -Sessions $Sessions

    Write-Log "Installing components on testbeds..."
    if ($InstallNodeMgr) {
        Install-Components -Session $Sessions[0] -InstallNodeMgr -ControllerIP $ControllerConfig.Address
        Install-Components -Session $Sessions[1] -InstallNodeMgr -ControllerIP $ControllerConfig.Address
    } else {
        Install-Components -Session $Sessions[0]
        Install-Components -Session $Sessions[1]
    }

    $ContrailNM = [ContrailNetworkManager]::new($OpenStackConfig, $ControllerConfig)
    Ensure-ContrailProject `
        -API $ContrailNM `
        -ProjectName $ControllerConfig.DefaultProject

    $Testbed1Address = $VMs[0].Address
    $Testbed1Name = $VMs[0].Name
    Write-Log "Creating virtual router. Name: $Testbed1Name; Address: $Testbed1Address"
    $VRouter1Uuid = Add-OrReplaceVirtualRouter `
        -API $ContrailNM `
        -RouterName $Testbed1Name `
        -RouterIp $Testbed1Address
    Write-Log "Reported UUID of new virtual router: $VRouter1Uuid"

    $Testbed2Address = $VMs[1].Address
    $Testbed2Name = $VMs[1].Name
    Write-Log "Creating virtual router. Name: $Testbed2Name; Address: $Testbed2Address"
    $VRouter2Uuid = Add-OrReplaceVirtualRouter `
        -API $ContrailNM `
        -RouterName $Testbed2Name `
        -RouterIp $Testbed2Address
    Write-Log "Reported UUID of new virtual router: $VRouter2Uuid"

    $Configs = [TestenvConfigs]::New($SystemConfig, $OpenStackConfig, $ControllerConfig)
    $VRoutersUuids = @($VRouter1Uuid, $VRouter2Uuid)
    return [MultiNode]::New($ContrailNM, $Configs, $Sessions, $VRoutersUuids, $InstallNodeMgr)
}

function Remove-MultiNodeSetup {
    Param (
        [Parameter(Mandatory=$true)] [MultiNode] $MultiNode
    )

    foreach ($VRouterUuid in $MultiNode.VRoutersUuids) {
        Write-Log "Removing virtual router: $VRouterUuid"
        Remove-ContrailVirtualRouter `
            -API $MultiNode.NM `
            -RouterUuid $VRouterUuid
    }
    $MultiNode.VRoutersUuids = $null

    Write-Log "Uninstalling components from testbeds..."
    foreach ($Session in $MultiNode.Sessions) {
        if ($MultiNode.InstalledNodeMgr) {
            Uninstall-Components -Session $Session -UninstallNodeMgr
        } else {
            Uninstall-Components -Session $Session
        }
    }

    Write-Log "Removing PS sessions.."
    Remove-PSSession $MultiNode.Sessions

    $MultiNode.Sessions = $null
    $MultiNode.NM = $null
}
