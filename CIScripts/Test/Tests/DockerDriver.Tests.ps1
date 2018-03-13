Param (
    [Parameter(Mandatory=$true)] [string] $TestbedAddr,
    [Parameter(Mandatory=$true)] [string] $ConfigFile
)

. $PSScriptRoot\..\Utils\CommonTestCode.ps1
. $PSScriptRoot\..\Utils\ComponentsInstallation.ps1
. $PSScriptRoot\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\..\Common\VMUtils.ps1
. $PSScriptRoot\..\PesterHelpers\PesterHelpers.ps1

. $ConfigFile
#$TestConf = Get-TestConfiguration
$Session = New-PSSession -ComputerName $TestbedAddr -Credential (Get-TestbedCredential)
$TestsPath = "C:\Program Files\Juniper Networks\"

function Start-DockerDriverUnitTest {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [string] $Component
    )

    $TestFilePath = ".\" + $Component + ".test.exe"
    $Command = @($TestFilePath, "--ginkgo.noisyPendings", "--ginkgo.failFast", "--ginkgo.progress", "--ginkgo.v", "--ginkgo.trace")
    $Command = $Command -join " "

    $Res = Invoke-Command -Session $Session -ScriptBlock {
        Push-Location $Using:TestsPath

        # Invoke-Command used as a workaround for temporary ErrorActionPreference modification
        $Res = Invoke-Command -ScriptBlock {
            $ErrorActionPreference = "SilentlyContinue"
            Invoke-Expression -Command $Using:Command | Write-Host
            return $LASTEXITCODE
        }

        Pop-Location

        return $Res
    }

    return $Res
}

function Save-DockerDriverUnitTestReport {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [string] $Component
    )

    Copy-Item -FromSession $Session -Path ($TestsPath + $_ + "_junit.xml") -ErrorAction SilentlyContinue
}

# TODO: these modules should also be tested: controller, hns, hnsManager, driver
$modules = @("agent")

if($Env:RUN_DRIVER_TESTS -eq "1") {
    Describe "Docker Driver" {
        $modules | ForEach-Object {
            Context "Tests for module $_" {
                It "Tests are invoked" {
                    Start-DockerDriverUnitTest -Session $Session -Component $_ | Should Be 0
                }

                AfterEach {
                    Save-DockerDriverUnitTestReport -Session $Session -Component $_
                }
            }
        }
    }
} else {
    Write-Host "Skipping Docker Driver tests."
}
