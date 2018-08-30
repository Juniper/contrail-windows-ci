. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\ComponentsInstallation.ps1

# Import order is chosen explicitly because of class dependency
. $PSScriptRoot\..\ContrailNetworkManager.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\MultiNode.ps1

function New-MultiNodeSetup {
    Param (
        [Parameter(Mandatory=$true)] [string] $TestenvConfFile
    )

    $VMs = Read-TestbedsConfig -Path $TestenvConfFile
    $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
    $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
    $SystemConfig = Read-SystemConfig -Path $TestenvConfFile

    $Sessions = New-RemoteSessions -VMs $VMs

    Write-Log "Installing components on testbeds..."
    Install-Components -Session $Sessions[0]
    Install-Components -Session $Sessions[1]

    $ContrailNM = [ContrailNetworkManager]::new($OpenStackConfig, $ControllerConfig)
    $ContrailNM.EnsureProject($ControllerConfig.DefaultProject)

    $Testbed1Address = $VMs[0].Address
    $Testbed1Name = $VMs[0].Name
    Write-Log "Creating virtual router. Name: $Testbed1Name; Address: $Testbed1Address"
    $VRouter1Uuid = $ContrailNM.AddVirtualRouter($Testbed1Name, $Testbed1Address)
    Write-Log "Reported UUID of new virtual router: $VRouter1Uuid"

    $Testbed2Address = $VMs[1].Address
    $Testbed2Name = $VMs[1].Name
    Write-Log "Creating virtual router. Name: $Testbed2Name; Address: $Testbed2Address"
    $VRouter2Uuid = $ContrailNM.AddVirtualRouter($Testbed2Name, $Testbed2Address)
    Write-Log "Reported UUID of new virtual router: $VRouter2Uuid"

    $Configs = [TestenvConfigs]::New($SystemConfig, $OpenStackConfig, $ControllerConfig)
    $VRoutersUuids = @($VRouter1Uuid, $VRouter2Uuid)
    return [MultiNode]::New($ContrailNM, $Configs, $Sessions, $VRoutersUuids)
}

function Remove-MultiNodeSetup {
    Param (
        [Parameter(Mandatory=$true)] [MultiNode] $MultiNode
    )

    foreach ($VRouterUuid in $MultiNode.VRoutersUuids) {
        Write-Log "Removing virtual router: $VRouterUuid"
        $MultiNode.NM.RemoveVirtualRouter($VRouterUuid)
    }
    $MultiNode.VRoutersUuids = $null

    Write-Log "Uninstalling components from testbeds..."
    foreach ($Session in $MultiNode.Sessions) {
        Uninstall-Components -Session $Session
    }

    Write-Log "Removing PS sessions.."
    Remove-PSSession $MultiNode.Sessions

    $MultiNode.Sessions = $null
    $MultiNode.NM = $null
}
