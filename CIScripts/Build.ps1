# Build builds selected Windows Compute components.
. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Build\BuildFunctions.ps1
. $PSScriptRoot\Build\BuildMode.ps1
. $PSScriptRoot\Build\Containers.ps1


$Job = [Job]::new("Build")

Initialize-BuildEnvironment -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH

$SconsBuildMode = Resolve-BuildMode

$CnmPluginOutputDir = "output/cnm-plugin"
$DockerDriverOutputDir = "output/docker-driver"
$vRouterOutputDir = "output/vrouter"
$vtestOutputDir = "output/vtest"
$AgentOutputDir = "output/agent"
$NodemgrOutputDir = "output/nodemgr"
$DllsOutputDir = "output/dlls"
$ContainersWorkDir = "output/containers"
$LogsDir = "logs"
$SconsTestsLogsDir = "unittests-logs"

$Directories = @(
    $CnmPluginOutputDir,
    $vRouterOutputDir,
    $vtestOutputDir,
    $AgentOutputDir,
    $NodemgrOutputDir,
    $DllsOutputDir,
    $ContainersWorkDir,
    $LogsDir,
    $SconsTestsLogsDir
)

foreach ($Directory in $Directories) {
    if (-not (Test-Path $Directory)) {
        New-Item -ItemType directory -Path $Directory | Out-Null
    }
}

try {
    Invoke-CnmPluginBuild -DriverSrcPath $Env:DRIVER_SRC_PATH `
        -SigntoolPath $Env:SIGNTOOL_PATH `
        -CertPath $Env:CERT_PATH `
        -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH `
        -OutputPath $CnmPluginOutputDir `
        -LogsPath $LogsDir

    Invoke-ExtensionBuild -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH `
        -SigntoolPath $Env:SIGNTOOL_PATH `
        -CertPath $Env:CERT_PATH `
        -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH `
        -BuildMode $SconsBuildMode `
        -OutputPath $vRouterOutputDir `
        -LogsPath $LogsDir

    Copy-VtestScenarios -OutputPath $vtestOutputDir

    Invoke-AgentBuild -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH `
        -SigntoolPath $Env:SIGNTOOL_PATH `
        -CertPath $Env:CERT_PATH `
        -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH `
        -BuildMode $SconsBuildMode `
        -OutputPath $AgentOutputDir `
        -LogsPath $LogsDir

    Invoke-NodemgrBuild -OutputPath $NodemgrOutputDir `
        -LogsPath $LogsDir `
        -BuildMode $SconsBuildMode

    # Building agent unit tests - disabled.
    # Invoke-AgentTestsBuild -LogsPath $LogsDir `
    #     -BuildMode $SconsBuildMode

    if ($SconsBuildMode -eq "debug") {
        Copy-DebugDlls -OutputPath $DllsOutputDir
    }

    if (Test-Path Env:DOCKER_REGISTRY) {
        Copy-Item -Path $CnmPluginOutputDir -Destination $DockerDriverOutputDir -Recurse

        $ContainersAttributes = @(
            [ContainerAttributes]::New("vrouter", @(
                $vRouterOutputDir,
                $AgentOutputDir,
                $NodemgrOutputDir
            )),
            [ContainerAttributes]::New("docker-driver", @(
                $DockerDriverOutputDir
            )),
            [ContainerAttributes]::New("cnm-plugin", @(
                $CnmPluginOutputDir
            ))
        )
        Invoke-ContainersBuild -WorkDir $ContainersWorkDir `
            -ContainersAttributes $ContainersAttributes `
            -ContainerTag "$Env:ZUUL_BRANCH-$Env:DOCKER_BUILD_NUMBER" `
            -Registry $Env:DOCKER_REGISTRY
    }

    Remove-PDBfiles -OutputPaths @($vRouterOutputDir, $AgentOutputDir)
} finally {
    $testDirs = Get-ChildItem ".\build\$SconsBuildMode" -Directory
    foreach ($d in $testDirs) {
        Copy-Item -Path $d.FullName -Destination $SconsTestsLogsDir `
            -Recurse -Filter "*.exe.log"
    }
}

$Job.Done()

exit 0
