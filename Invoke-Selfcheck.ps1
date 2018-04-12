Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [switch] $SkipUnit,
    [switch] $NoStaticAnalysis
)

# NOTE TO DEVELOPERS
# ------------------
# The idea behind this tool is that anyone can run the basic set of tests without ANY preparation.
# A new developer should be able to run .\Invoke-Selfcheck.ps1 and it should pass 100% of the time,
# without any special requirements, like libraries, testbed machines etc.
# Special flags may be passed to invoke more complicated tests (that have requirements), but
# the default should require nothing.

$nl = [Environment]::NewLine

function Get-Separator {
    $nl + ((@("=") * 80) -join "") + $nl
}

function Write-VisibleMessage {
    param([string] $Message)
    Write-Host "$(Get-Separator)[Selfcheck] $Message$(Get-Separator)"
}

if ($SkipUnit) {
    Write-VisibleMessage "-SkipUnit flag set, skipping unit tests"
} else {
    Write-VisibleMessage "performing unit tests"
    Invoke-Pester -Tags CI_Unit
}

if ($TestenvConfFile) {
    Write-VisibleMessage "performing system tests"
    Invoke-Pester -Tags CI_Systest -Script @{Path="."; Parameters=@{TestenvConfFile=$TestenvConfFile};}
} else {
    Write-VisibleMessage "testenvconf file not provided, skipping system tests"
}

if ($NoStaticAnalysis) {
    Write-VisibleMessage "-NoStaticAnalysis switch set, skipping static analysis"
} elseif (-not (Get-Module PSScriptAnalyzer)) {
    Write-VisibleMessage "PSScriptAnalyzer module not found. Skipping static analysis.
        You can install it by running `Install-Module -Name PSScriptAnalyzer`."
} else {
    Write-VisibleMessage "running static analysis, this might take a while"
    .\StaticAnalysis\Invoke-StaticAnalysisTools.ps1 -RootDir . -ConfigDir $pwd/StaticAnalysis
}

Write-VisibleMessage "done"
