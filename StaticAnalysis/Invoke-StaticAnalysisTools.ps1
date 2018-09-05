Param([Parameter(Mandatory = $true)] [string] $RootDir,
      [Parameter(Mandatory = $true)] [string] $ConfigDir,
      [string] $MinimumVersion = "1.17.0")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-MinimalAnalyzerVersion($MinimumVersion) {
    try {
        # Maybe it was installed using PSGet?
        $Analyzer = Get-Package -Name PSScriptAnalyzer
    } catch {
        # Maybe it was installed by chocolatey?
        $Analyzer = Get-Module -Name PSScriptAnalyzer
    }
    if ($Analyzer.Version -lt $MinimumVersion) {
        Write-Host "PSScriptAnalyzer not found. If you have installed it, make sure that it's at least version $MinimumVersion."
        exit 1
    }
}

function Remove-TypeNotFoundWarning ($Data) {
    # WORKAROUND
    # TypeNotFound error is fixed in 1.17.0 PSScriptAnalyzer, but it still produces a warning.
    # Moreover, this warning cannot be surpressed in script analyzer settings. 
    # We still want to treat warnings as errors, so the only way is to filter out this warning
    # out of the analyzer output. Until issue [1] is resolved TypeNotFound cannot be
    # suppressed like all the other errors.
    # [1] https://github.com/PowerShell/PSScriptAnalyzer/issues/1041
    $Output | Where-Object -FilterScript { $_.RuleName -ne "TypeNotFound" }
}

function Write-Results ($Data) {
    Write-Host ($Data | Format-Table | Out-String)
}

$PSLinterConfig = "$ConfigDir/PSScriptAnalyzerSettings.psd1"
Write-Host "Running PSScriptAnalyzer... (config from $PSLinterConfig)"
Test-MinimalAnalyzerVersion($MinimumVersion)
$Output = Invoke-ScriptAnalyzer $RootDir -Recurse -Setting $PSLinterConfig
$Output = Remove-TypeNotFoundWarning $Output
if ($Output) {
    Write-Results $Output
    exit 1
}
exit 0
