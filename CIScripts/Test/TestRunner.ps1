. $PSScriptRoot\TestConfigurationUtils.ps1
. $PSScriptRoot\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\TestRunner\Invoke-PesterTests.ps1

function Invoke-IntegrationAndFunctionalTests {
    Param (
        [Parameter(Mandatory = $true)] [String] $TestenvConfFile,
        [Parameter(Mandatory = $true)] [String] $PesterOutReportPath,
        [Parameter(Mandatory = $true)] [String] $DetailedLogsOutputDir,
        [Parameter(Mandatory = $true)] [String] $AdditionalJUnitsDir
    )
    # TODO: Maybe we should collect codecov statistics similarly in the future?

    # TODO2: Changing AdditionalParams force us to modify all the tests that use it -> maybe find a better way to pass them?
    $AdditionalParams = @{
        TestenvConfFile=$TestenvConfFile;
        LogDir=$DetailedLogsOutputDir;
        AdditionalJUnitsDir=$AdditionalJUnitsDir;
    }
    $Results = Invoke-PesterTests -TestRootDir $pwd -ReportPath $PesterOutReportPath `
        -ExcludeTags CI -AdditionalParams $AdditionalParams
    if ($Results.FailedCount -gt 0) {
        throw "Some tests failed"
    }
}
