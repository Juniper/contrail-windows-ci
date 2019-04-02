. $PSScriptRoot\..\..\Test\Utils\PowershellTools\Invoke-NativeCommand.ps1
. $PSScriptRoot\..\Build\Repository.ps1

$PdbSubfolder = "pdb"

function Initialize-BuildEnvironment {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache)
    $Job.Step("Copying common third-party dependencies", {
        if (!(Test-Path -Path .\third_party)) {
            New-Item -ItemType Directory .\third_party | Out-Null
        }
        Get-ChildItem "$ThirdPartyCache\common" -Directory |
            Where-Object{$_.Name -notlike "boost*"} |
            Copy-Item -Destination third_party\ -Recurse -Force
    })

    $Job.Step("Copying SConstruct from tools\build", {
        Copy-Item tools\build\SConstruct .
    })
}

function Invoke-CnmPluginBuild {
    Param ([Parameter(Mandatory = $true)] [string] $PluginSrcPath,
           [Parameter(Mandatory = $true)] [string] $OutputPath)

    $Job.PushStep("CNM plugin build")
    $GoPath = Get-Location
    if (Test-Path Env:GOPATH) {
        $GoPath +=  ";$Env:GOPATH"
    }
    $Env:GOPATH = $GoPath
    $srcPath = "$GoPath/src/$PluginSrcPath"

    New-Item -ItemType Directory ./bin | Out-Null

    Push-Location $srcPath
    $Job.Step("Fetch third party packages ", {
        Invoke-NativeCommand -ScriptBlock {
            & dep ensure -v
        }
    })
    Pop-Location # $srcPath

    $Job.Step("Contrail-go-api source code generation", {
        Invoke-NativeCommand -ScriptBlock {
            py src/contrail-api-client/generateds/generateDS.py -q -f `
                                    -o $srcPath/vendor/github.com/Juniper/contrail-go-api/types/ `
                                    -g golang-api src/contrail-api-client/schema/vnc_cfg.xsd

            # Workaround on https://github.com/golang/go/issues/18468
            Copy-Item -Path $srcPath/vendor/* -Destination $GoPath/src -Force -Recurse
            Remove-Item -Path $srcPath/vendor -Force -Recurse
        }
    })

    $Job.Step("Building plugin and precompiling tests", {
        # TODO: Handle new name properly
        Push-Location $srcPath
        Invoke-NativeCommand -ScriptBlock {
            & $srcPath\Invoke-Build.ps1
        }
        Pop-Location # $srcPath
    })


    $Job.Step("Copying artifacts to $OutputPath", {
        Copy-Item -Path $srcPath\build\* -Include "*.msi", "*.exe" -Destination $OutputPath
    })

    $Job.PopStep()
}

function Invoke-ExtensionBuild {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $false)] [string] $BuildMode = "debug")

    $Job.PushStep("Extension build")

    $Job.Step("Copying Extension dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\extension\*" third_party\
    })

    $Job.Step("Building Extension and Utils", {
        Invoke-NativeCommand -ScriptBlock {
            scons --opt=$BuildMode vrouter
        } | Out-Null
    })

    $vRouterBuildRoot = "build\{0}\vrouter" -f $BuildMode
    $vRouterMSI = "$vRouterBuildRoot\extension\vRouter.msi"
    $vRouterCert = "$vRouterBuildRoot\extension\vRouter.cer"
    $utilsMSI = "$vRouterBuildRoot\utils\utils.msi"

    $pdbOutputPath = "$OutputPath\$PdbSubfolder"
    $vRouterPdbFiles = "$vRouterBuildRoot\extension\*.pdb"

    $Job.Step("Copying artifacts to $OutputPath", {
        Copy-Item $utilsMSI $OutputPath
        Copy-Item $vRouterMSI $OutputPath
        Copy-Item $vRouterCert $OutputPath
        New-Item $pdbOutputPath -Type Directory -Force
        Copy-Item $vRouterPdbFiles $pdbOutputPath
    })

    $Job.PopStep()
}

function Copy-VtestScenarios {
    Param ([Parameter(Mandatory = $true)] [string] $OutputPath)

    $Job.Step("Copying vtest scenarios to $OutputPath", {
        $vTestSrcPath = "vrouter\utils\vtest\"
        Copy-Item "$vTestSrcPath\tests" $OutputPath -Recurse -Filter "*.xml"
        Copy-Item "$vTestSrcPath\*.ps1" $OutputPath
    })
}

function Invoke-AgentBuild {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $false)] [string] $BuildMode = "debug")

    $Job.PushStep("Agent build")

    $Job.Step("Copying Agent dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\agent\*" third_party/
    })

    $Job.Step("Building contrail-vrouter-agent.exe and .msi", {
        Invoke-NativeCommand -ScriptBlock {
            scons -j $Env:BUILD_THREADS --opt=$BuildMode contrail-vrouter-agent.msi
        } | Out-Null
    })

    $agentMSI = "build\$BuildMode\vnsw\agent\contrail\contrail-vrouter-agent.msi"

    $pdbOutputPath = "$OutputPath\$PdbSubfolder"
    $agentPdbFiles = "build\$BuildMode\vnsw\agent\contrail\*.pdb"

    $Job.Step("Copying artifacts to $OutputPath", {
        Copy-Item $agentMSI $OutputPath -Recurse
        New-Item $pdbOutputPath -Type Directory -Force
        Copy-Item $agentPdbFiles $pdbOutputPath -Recurse
    })

    $Job.PopStep()
}

function Invoke-NodemgrBuild {
    Param ([Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $false)] [string] $BuildMode = "debug")

    $Job.PushStep("Nodemgr build")

    $Job.Step("Building nodemgr", {
        $Components = @(
            "database:node_mgr",
            "build/$BuildMode/sandesh/common/dist",
            "sandesh/library/python:pysandesh",
            "vrouter:node_mgr",
            "contrail-nodemgr"
        )

        Invoke-NativeCommand -ScriptBlock {
            scons -j $Env:BUILD_THREADS --opt=$BuildMode @Components
        } | Out-Null
    })

    $Job.Step("Copying artifacts to $OutputPath", {
        $ArchivesFolders = @(
            "analytics\database",
            "sandesh\common",
            "tools\sandesh\library\python",
            "vnsw\agent\uve",
            "nodemgr"
        )
        ForEach ($ArchiveFolder in $ArchivesFolders) {
            Copy-Item "build\$BuildMode\$ArchiveFolder\dist\*.tar.gz" $OutputPath
        }
    })

    $Job.PopStep()
}

function Remove-PdbFiles {
    Param ([Parameter(Mandatory = $true)] [string[]] $OutputPaths)

    ForEach ($OutputPath in $OutputPaths) {
        Remove-Item "$OutputPath\$PdbSubfolder" -Recurse -ErrorAction Ignore
    }
}

function Copy-DebugDlls {
    Param ([Parameter(Mandatory = $true)] [string] $OutputPath)

    $Job.Step("Copying dlls to $OutputPath", {
        foreach ($Lib in @("ucrtbased.dll", "vcruntime140d.dll", "msvcp140d.dll")) {
            Copy-Item "C:\Windows\System32\$Lib" $OutputPath
        }
    })
}

function Invoke-ProductUnitTests {
    Param ([Parameter(Mandatory = $false)] [string] $BuildMode = "debug")

    $Job.Step("Building and running unit tests", {
        $Tests = @(
            'src/contrail-common/base:test',
            'kernel-tests',
            'vrouter:test'
        )

        $backupPath = $Env:Path
        $Env:Path += ";" + $(Get-Location).Path + "\build\bin"

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "", Justification="TASK_UTIL_WAIT_TIME is used agent tests for determining timeout's " +
            "threshold. They were copied from Linux unit test job.")]
        $Env:TASK_UTIL_WAIT_TIME = 10000

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "", Justification="TASK_UTIL_RETRY_COUNT is used in agent tests for determining " +
            "timeout's threshold. They were copied from Linux unit test job.")]
        $Env:TASK_UTIL_RETRY_COUNT = 6000

        Invoke-NativeCommand -ScriptBlock {
            scons -j $Env:BUILD_THREADS --opt=$BuildMode @Tests
        } | Out-Null

        $Env:Path = $backupPath
    })
}
