. $PSScriptRoot\TestConfigurationUtils.ps1
. $PSScriptRoot\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\TestRunner\Invoke-PesterTests.ps1

function Invoke-TestScenarios {
    Param (
        [Parameter(Mandatory = $true)] [String] $TestenvConfFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    $DetailedLogDir = Join-Path $TestReportOutputDirectory "detailed"
    $AdditionalJUnitsDir = Join-Path $TestReportOutputDirectory "junit"
    # TODO: Maybe we should collect codecov statistics similarly in the future?

    $AdditionalParams = @{
        TestenvConfFile=$TestenvConfFile;
        LogDir=$DetailedLogDir;
        AdditionalJUnitsDir=$AdditionalJUnitsDir;
    }
    $Results = Invoke-PesterTests -TestRootDir $pwd -ReportDir $TestReportOutputDirectory `
        -ExcludeTags CI -AdditionalParams $AdditionalParams
    if ($Results.FailedCount -gt 0) {
        throw "Some tests failed"
    }
}

function Invoke-IntegrationAndFunctionalTests {
    Param (
        [Parameter(Mandatory = $true)] [String] $TestenvConfFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
    $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
    $ContrailNM = [ContrailNetworkManager]::new($OpenStackConfig, $ControllerConfig)
    $ContrailNM.EnsureProject($null)

    Invoke-TestScenarios `
        -TestenvConfFile $TestenvConfFile `
        -TestReportOutputDirectory $TestReportOutputDirectory
}
