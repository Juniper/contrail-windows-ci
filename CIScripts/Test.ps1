Param(
    [Parameter(Mandatory = $true)] [string] $TestRootDir,
    [Parameter(Mandatory = $true)] [string] $TestReportDir,
    [Parameter(Mandatory = $true)] [string] $TestenvConfFile
)

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\..\Test\TestRunner.ps1

$Job = [Job]::new("Test")

if (-not (Test-Path $TestReportDir)) {
    New-Item -ItemType Directory -Path $TestReportDir | Out-Null
}

$DetailedLogsDir = Join-Path $TestReportDir "detailed_logs"
$CnmPluginJUnitLogsOutputDir = Join-Path $TestReportDir "cnm_plugin_junit_test_logs"

$PesterOutReportDir = Join-Path $TestReportDir "raw_NUnit" 
$PesterOutReportPath = Join-Path $PesterOutReportDir "report.xml"

Invoke-IntegrationAndFunctionalTests `
    -TestRootDir $TestRootDir `
    -TestenvConfFile $TestenvConfFile `
    -PesterOutReportPath $PesterOutReportPath `
    -DetailedLogsOutputDir $DetailedLogsDir `
    -AdditionalJUnitsDir $CnmPluginJUnitLogsOutputDir

$Job.Done()
