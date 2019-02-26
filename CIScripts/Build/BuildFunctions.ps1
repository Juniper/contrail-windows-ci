. $PSScriptRoot\..\Common\Invoke-NativeCommand.ps1
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

function Set-MSISignature {
    Param ([Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $MSIPath)
    $Job.Step("Signing MSI", {
        $cerp = Get-Content $CertPasswordFilePath
        Invoke-NativeCommand -ScriptBlock {
            & $SigntoolPath sign /f $CertPath /p $cerp $MSIPath
        }
    })
}

function Invoke-CnmPluginBuild {
    Param ([Parameter(Mandatory = $true)] [string] $PluginSrcPath,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $true)] [string] $LogsPath)

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

    $Job.Step("Signing MSI", {
        Push-Location $OutputPath

        foreach ($msi in (Get-ChildItem "*.msi")) {
            Set-MSISignature -SigntoolPath $SigntoolPath `
                             -CertPath $CertPath `
                             -CertPasswordFilePath $CertPasswordFilePath `
                             -MSIPath $msi.FullName
        }

        Pop-Location # $OutputPath
    })

    $Job.PopStep()
}

function Invoke-ExtensionBuild {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $true)] [string] $LogsPath,
           [Parameter(Mandatory = $false)] [string] $BuildMode = "debug")

    $Job.PushStep("Extension build")

    $Job.Step("Copying Extension dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\extension\*" third_party\
    })

    $BuildModeOption = "--optimization=" + $BuildMode

    $Job.Step("Building Extension and Utils", {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "", Justification="Cerp env variable required by vRouter build.")]
        $Env:cerp = Get-Content $CertPasswordFilePath

        Invoke-NativeCommand -ScriptBlock {
            scons $BuildModeOption vrouter | Tee-Object -FilePath $LogsPath/vrouter_build.log
        }
    })

    $Job.Step("Running kernel unit tests", {
        Invoke-NativeCommand -ScriptBlock {
            scons $BuildModeOption kernel-tests vrouter:test | Tee-Object -FilePath $LogsPath/vrouter_unit_tests.log
        }
    })

    $vRouterBuildRoot = "build\{0}\vrouter" -f $BuildMode
    $vRouterMSI = "$vRouterBuildRoot\extension\vRouter.msi"
    $vRouterCert = "$vRouterBuildRoot\extension\vRouter.cer"
    $utilsMSI = "$vRouterBuildRoot\utils\utils.msi"

    $pdbOutputPath = "$OutputPath\$PdbSubfolder"
    $vRouterPdbFiles = "$vRouterBuildRoot\extension\*.pdb"

    Write-Host "Signing utilsMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath $utilsMSI

    Write-Host "Signing vRouterMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath $vRouterMSI

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
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $true)] [string] $LogsPath,
           [Parameter(Mandatory = $false)] [string] $BuildMode = "debug")

    $Job.PushStep("Agent build")

    $Job.Step("Copying Agent dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\agent\*" third_party/
    })

    $Job.Step("Building contrail-vrouter-agent.exe and .msi", {
        if(Test-Path Env:AGENT_BUILD_THREADS) {
            $Threads = $Env:AGENT_BUILD_THREADS
        } else {
            $Threads = 1
        }
        $AgentBuildCommand = "scons -j {0} --opt={1} contrail-vrouter-agent.msi" -f $Threads, $BuildMode
        Invoke-NativeCommand -ScriptBlock {
            Invoke-Expression $AgentBuildCommand | Tee-Object -FilePath $LogsPath/build_agent.log
        }
    })

    $agentMSI = "build\$BuildMode\vnsw\agent\contrail\contrail-vrouter-agent.msi"

    $pdbOutputPath = "$OutputPath\$PdbSubfolder"
    $agentPdbFiles = "build\$BuildMode\vnsw\agent\contrail\*.pdb"

    Write-Host "Signing agentMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath $agentMSI

    $Job.Step("Copying artifacts to $OutputPath", {
        Copy-Item $agentMSI $OutputPath -Recurse
        New-Item $pdbOutputPath -Type Directory -Force
        Copy-Item $agentPdbFiles $pdbOutputPath -Recurse
    })

    $Job.PopStep()
}

function Invoke-NodemgrBuild {
    Param ([Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $true)] [string] $LogsPath,
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
            scons --opt=$BuildMode @Components | Tee-Object -FilePath $LogsPath/build_nodemgr.log
        }
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

function Remove-PDBfiles {
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

function Get-FailedUnitTests {
    Param ([Parameter(Mandatory = $true)] [Object[]] $TestOutput)
    $FailedTests = @()
    Foreach ($Line in $TestOutput) {
        if ($Line -match "\[  FAILED  \] (?<FailedTest>\D\S*)\s\(\d*\sms\)$") {
            $FailedTests += $matches.FailedTest
        }
    }
    return ,$FailedTests
}

function Invoke-AgentUnitTestRunner {
    Param (
        [Parameter(Mandatory = $true)] [String] $TestExecutable
    )

    Write-Host "===> Agent tests: running $TestExecutable..."
    $Res = Invoke-Command -ScriptBlock {
        $TestExecDir = Split-Path $TestExecutable

        $Command = Invoke-NativeCommand -AllowNonZero -CaptureOutput -ScriptBlock {
            # TODO: Delete the tee-object part when using aliases instead of raw filepaths
            Invoke-Expression $TestExecutable | Tee-Object -FilePath "$TestExecutable.log"
        }

        $Result = @{}
        # This is a workaround for the following bug:
        # https://bugs.launchpad.net/opencontrail/+bug/1714205
        # Even if all tests actually pass, test executables can sometimes
        # return non-zero exit code.
        # TODO: It should be removed once the bug is fixed (JW-1110).
        $Result.FailedTests = Get-FailedUnitTests -TestOutput $Command.Output
        $Result.ExitCode = $Command.ExitCode
        if (-not $Result.FailedTests.Count) {
            $Result.ExitCode = 0
        }

        return $Result
    }

    if (-not $Res.ExitCode) {
        Write-Host "   Succeeded."
    } else {
        $FailedTests = $Res.FailedTests -join [Environment]::NewLine
        Write-Host "   Failed:`r`n exit code: $($Res.ExitCode) `r`n failed tests: `r`n $FailedTests "
    }

    return $Res.ExitCode
}

function Invoke-AgentTestsBuild {
    Param ([Parameter(Mandatory = $true)] [string] $LogsPath,
           [Parameter(Mandatory = $false)] [string] $BuildMode = "debug")

    $Job.PushStep("Agent Tests build")

    $BuildModeOption = "--optimization=" + $BuildMode

    $TestPathPrefix = "build/$BuildMode"
    $BaseTestPrefix = "$TestPathPrefix/base/test"
    # $AgentPathPrefix = "$TestPathPrefix/vnsw/agent"

    $Job.Step("Building agent tests", {
        $Tests = @(
            "$BaseTestPrefix/trace_test.exe"
            "$BaseTestPrefix/timer_test.exe"
            "$BaseTestPrefix/test_task_monitor.exe"
            "$BaseTestPrefix/subset_test.exe"
            "$BaseTestPrefix/queue_task_test.exe"
            "$BaseTestPrefix/patricia_test.exe"
            "$BaseTestPrefix/label_block_test.exe"
            "$BaseTestPrefix/factory_test.exe"
            "$BaseTestPrefix/index_allocator_test.exe"
            "$BaseTestPrefix/dependency_test.exe"
            "$BaseTestPrefix/bitset_test.exe"

            #"src/contrail-common/base:test"
            # "src/contrail-common/io:test"
            # "controller/src/agent:test"
            # "vrouter:test"
        )

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "", Justification="TASK_UTIL_WAIT_TIME is used agent tests for determining timeout's " +
            "threshold. They were copied from Linux unit test job.")]
        $Env:TASK_UTIL_WAIT_TIME = 10000

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "", Justification="TASK_UTIL_RETRY_COUNT is used agent tests for determining " +
            "timeout's threshold. They were copied from Linux unit test job.")]
        $Env:TASK_UTIL_RETRY_COUNT = 6000

        $TestsString = $Tests -join " "
        $TestsBuildCommand = "scons -k --debug=explain -j 4 {0} {1}" -f "$BuildModeOption", "$TestsString"

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "", Justification="Env variable is used by another executable")]
        $Env:BUILD_ONLY = "1"

        Invoke-NativeCommand -ScriptBlock {
            Invoke-Expression $TestsBuildCommand | Tee-Object -FilePath $LogsPath/build_agent_tests.log
        } | Out-Null

        Remove-Item Env:\BUILD_ONLY
    })

    $rootBuildDir = "build\$BuildMode"

    $Job.Step("Running agent tests", {
        $backupPath = $Env:Path
        $Env:Path += ";" + $(Get-Location).Path + "\build\bin"

        $TestsFolders = @(
            "base\test",
            "dns\test",
            "ksync\test",
            "schema\test",
            "vnsw\agent\cmn\test",
            "vnsw\agent\oper\test",
            "vnsw\agent\test",
            "xml\test",
            "xmpp\test"
        ) | ForEach-Object { Join-Path $rootBuildDir $_ }

        $AgentExecutables = Get-ChildItem -Recurse $TestsFolders | Where-Object {$_.Name -match '.*?\.exe$'}
        # TODO: Some unit tests of Agent need DLLs present in the same
        # directory as executable.
        $TestRes = $AgentExecutables | ForEach-Object {
            Invoke-AgentUnitTestRunner -TestExecutable $( $_.FullName )
        }

        $TestRes | ForEach-Object {
            if (0 -ne $_) {
                throw "Running agent tests failed"
            }
        }

        $Env:Path = $backupPath
    })

    $Job.PopStep()
}
