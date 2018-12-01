. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\ComputeNode\Installation.ps1
. $PSScriptRoot\..\ContrailAPI\SecurityGroup.ps1

. $PSScriptRoot\..\ContrailAPI_New\Project.ps1
. $PSScriptRoot\..\ContrailAPI_New\VirtualRouter.ps1

# Import order is chosen explicitly because of class dependency
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\MultiNode.ps1

function Set-ConfAndLogDir {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )
    $ConfigDirPath = Get-DefaultConfigDir
    $LogDirPath = Get-ComputeLogsDir

    foreach ($Session in $Sessions) {
        Invoke-Command -Session $Session -ScriptBlock {
            New-Item -ItemType Directory -Path $using:ConfigDirPath -Force | Out-Null
            New-Item -ItemType Directory -Path $using:LogDirPath -Force | Out-Null
        } | Out-Null
    }
}

function New-MultiNodeSetup {
    Param (
        [Parameter(Mandatory = $true)] [string] $TestenvConfFile
    )

    $VMs = Read-TestbedsConfig -Path $TestenvConfFile
    $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
    $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
    $SystemConfig = Read-SystemConfig -Path $TestenvConfFile
    $Configs = [TestenvConfigs]::New($SystemConfig, $OpenStackConfig, $ControllerConfig)

    $Sessions = New-RemoteSessions -VMs $VMs

    Set-ConfAndLogDir -Sessions $Sessions

    $ContrailNM = [ContrailNetworkManager]::new($Configs)
    $ProjectRepo = [ProjectRepo]::new($ContrailNM)
    $VirtualRouterRepo = [VirtualRouterRepo]::new($ContrailNM)

    $Project = [Project]::new($ContrailNM.DefaultTenantName)
    $ProjectRepo.AddOrReplace($Project) | Out-Null

    Add-OrReplaceContrailSecurityGroup `
        -API $ContrailNM `
        -TenantName $ContrailNM.DefaultTenantName `
        -Name 'default' | Out-Null

    $VRoutersUuids = @()
    foreach ($VM in $VMs) {
        Write-Log "Creating virtual router. Name: $($VM.Name); Address: $($VM.Address)"
        $VirtualRouter = [VirtualRouter]::new($VM.Name, $VM.Address)
        $VRouterUuid = $VirtualRouterRepo.AddOrReplace($VirtualRouter)
        Write-Log "Reported UUID of new virtual router: $VRouterUuid"
        $VRoutersUuids += $VRouterUuid
    }

    return [MultiNode]::New($ContrailNM, $Configs, $Sessions, $VRoutersUuids)
}

function Remove-MultiNodeSetup {
    Param (
        [Parameter(Mandatory = $true)] [MultiNode] $MultiNode
    )

    $VirtualRouterRepo = [VirtualRouterRepo]::new($MultiNode.NM)
    $ProjectRepo = [ProjectRepo]::new($ContrailNM)

    foreach ($VRouterUuid in $MultiNode.VRoutersUuids) {
        Write-Log "Removing virtual router: $VRouterUuid"
        $VirtualRouter = [VirtualRouter]::new('unknown', 'unknown')
        $VirtualRouter.Uuid = $VRouterUuid
        $VirtualRouterRepo.Remove($VirtualRouter)
    }
    $MultiNode.VRoutersUuids = $null

    $Project = [Project]::new($ContrailNM.DefaultTenantName)
    $ProjectRepo.RemoveWithDependencies($Project)

    Write-Log "Removing PS sessions.."
    Remove-PSSession $MultiNode.Sessions

    $MultiNode.Sessions = $null
    $MultiNode.NM = $null
}
