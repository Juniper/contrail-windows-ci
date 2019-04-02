# Build builds selected Windows Compute components.
. $PSScriptRoot\..\Test\Utils\PowershellTools\Init.ps1
. $PSScriptRoot\Job.ps1
. $PSScriptRoot\Build\BuildFunctions.ps1
. $PSScriptRoot\Build\BuildMode.ps1
. $PSScriptRoot\Build\Containers.ps1


$Job = [Job]::new("Build")

Initialize-BuildEnvironment -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH

$SconsBuildMode = Resolve-BuildMode

$CnmPluginOutputDir = "output/cnm-plugin"
$vRouterOutputDir = "output/vrouter"
$vtestOutputDir = "output/vtest"
$AgentOutputDir = "output/agent"
$NodemgrOutputDir = "output/nodemgr"
$DllsOutputDir = "output/dlls"
$ContainersWorkDir = "output/containers"
$SconsTestsLogsDir = "unittests-logs"

$Directories = @(
    $CnmPluginOutputDir,
    $vRouterOutputDir,
    $vtestOutputDir,
    $AgentOutputDir,
    $NodemgrOutputDir,
    $DllsOutputDir,
    $ContainersWorkDir,
    $SconsTestsLogsDir
)

foreach ($Directory in $Directories) {
    if (-not (Test-Path $Directory)) {
        New-Item -ItemType directory -Path $Directory | Out-Null
    }
}

try {
    Invoke-CnmPluginBuild -PluginSrcPath $Env:CNM_PLUGIN_SRC_PATH `
        -OutputPath $CnmPluginOutputDir

    Invoke-ExtensionBuild -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH `
        -BuildMode $SconsBuildMode `
        -OutputPath $vRouterOutputDir

    Copy-VtestScenarios -OutputPath $vtestOutputDir

    Invoke-AgentBuild -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH `
        -BuildMode $SconsBuildMode `
        -OutputPath $AgentOutputDir

    Invoke-NodemgrBuild -OutputPath $NodemgrOutputDir `
        -BuildMode $SconsBuildMode

    Invoke-ProductUnitTests -BuildMode $SconsBuildMode

    if ("debug" -eq $SconsBuildMode) {
        Copy-DebugDlls -OutputPath $DllsOutputDir
    }

    if (Test-Path Env:DOCKER_REGISTRY) {
        $ContainersAttributes = @(
            [ContainerAttributes]::New("vrouter", @(
                $vRouterOutputDir,
                $AgentOutputDir,
                $NodemgrOutputDir
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

    Remove-PdbFiles -OutputPaths @($vRouterOutputDir, $AgentOutputDir)
} finally {
    $testDirs = Get-ChildItem ".\build\$SconsBuildMode" -Directory
    foreach ($d in $testDirs) {
        Copy-Item -Path $d.FullName -Destination $SconsTestsLogsDir `
            -Recurse -Filter "*.exe.log"
    }
}

$Job.Done()

exit 0
