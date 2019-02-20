Param(
    [Parameter(Mandatory = $true)] [string] $TestRootDir,
    [Parameter(Mandatory = $true)] [string] $TestReportDir,
    [Parameter(Mandatory = $true)] [string] $TestenvConfFile,
    [Parameter(Mandatory = $false)] [switch] $Nightly
)

. $PSScriptRoot\..\Test\Utils\PowershellTools\Init.ps1
. $PSScriptRoot\Job.ps1

$Job = [Job]::new("Test")

try {
    . $PSScriptRoot\..\Test\Invoke-ProductTests.ps1 `
        -TestRootDir $TestRootDir `
        -TestReportDir $TestReportDir `
        -TestenvConfFile $TestenvConfFile `
        -SmokeTestsOnly:$(!$Nightly)
}
catch {
    Write-Host 'Invoke-ProductTests.ps1 has thrown an exception'
    throw
}
finally {
    $Job.Done()
}

$Error.Clear()
exit 0
