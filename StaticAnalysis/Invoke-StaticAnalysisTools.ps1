Param([Parameter(Mandatory = $true)] [string] $RootDir,
      [Parameter(Mandatory = $true)] [string] $ConfigDir)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PSLinterConfig = "$ConfigDir/PSScriptAnalyzerSettings.psd1"
Write-Host "Running PSScriptAnalyzer... (config from $PSLinterConfig)"

$Output = Invoke-ScriptAnalyzer $RootDir -Recurse -Setting $PSLinterConfig

# TypeNotFound errors are still reported. Until this issue [1] is resolved TypeNotFound cannot be
# suppressed like all the other errors.
#
# [1] https://github.com/PowerShell/PSScriptAnalyzer/issues/1041
$Output = $Output | Where-Object -FilterScript { $_.RuleName -ne "TypeNotFound" }

if ($Output) {
      Write-Host ($Output | Format-Table | Out-String)
      exit 1
}

exit 0
