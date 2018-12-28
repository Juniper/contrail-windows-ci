. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\ComputeNode\Installation.ps1
. $PSScriptRoot\..\ComputeNode\TestsRequirements.ps1
. $PSScriptRoot\..\ContrailAPI_New\ContrailAPI.ps1

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
        [Parameter(Mandatory = $true)] [Testbed[]] $Testbeds,
        [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig,
        [Parameter(Mandatory = $false)] [OpenStackConfig] $OpenStackConfig,
        [Parameter(Mandatory = $true)] [String] $ContrailProject
    )

    # For old API
    $ContrailNM = [ContrailNetworkManager]::new($ControllerConfig, $OpenStackConfig)
    # For new API
    $ContrailRestApi = [ContrailRestApi]::new($ControllerConfig, $OpenStackConfig)

    $ContrailRepo = [ContrailRepo]::new($ContrailRestApi)

    $Project = [Project]::new($ContrailProject)
    $ContrailRepo.AddOrReplace($Project) | Out-Null

    $SecurityGroup = [SecurityGroup]::new_Default($ContrailProject)
    $ContrailRepo.AddOrReplace($SecurityGroup) | Out-Null

    $VRouters = @()
    foreach ($Testbed in $Testbeds) {
        Write-Log "Creating virtual router. Name: $($Testbed.Name); Address: $($Testbed.Address)"
        $VirtualRouter = [VirtualRouter]::new($Testbed.Name, $Testbed.Address)
        $Response = $ContrailRepo.AddOrReplace($VirtualRouter)
        Write-Log "Reported UUID of new virtual router: $($Response.'virtual-router'.'uuid')"
        $VRouters += $VirtualRouter
    }

    return [MultiNode]::New($ContrailNM, $ContrailRestApi, $VRouters, $Project)
}

function Remove-MultiNodeSetup {
    Param (
        [Parameter(Mandatory = $true)] [MultiNode] $MultiNode
    )
    $ContrailRepo = [ContrailRepo]::new($MultiNode.ContrailRestApi)

    foreach ($VRouter in $MultiNode.VRouters) {
        Write-Log "Removing virtual router: $($VRouter.Name)"
        $ContrailRepo.Remove($VRouter)
    }
    $MultiNode.VRouters = $null

    Write-Log "Removing project: $($MultiNode.Project.Name) with dependencies"
    $ContrailRepo.RemoveWithDependencies($MultiNode.Project)
    $MultiNode.Project = $null

    Write-Log 'Removing PS sessions'

    $MultiNode.NM = $null
}
