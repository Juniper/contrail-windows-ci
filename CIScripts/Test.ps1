Param(
    [Parameter(Mandatory = $true)] [string] $TestRootDir,
    [Parameter(Mandatory = $true)] [string] $TestReportDir,
    [Parameter(Mandatory = $true)] [string] $TestenvConfFile,
    [Parameter(Mandatory = $false)] [switch] $Nightly
)

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1

$Job = [Job]::new("Test")

try {
    . $PSScriptRoot\..\Test\Invoke-ProductTests.ps1 `
        -TestRootDir $TestRootDir `
        -TestReportDir $TestReportDir `
        -TestenvConfFile $TestenvConfFile `
        -SmokeTestsOnly:$(!$Nightly)
}
finally {
    $Job.Done()
}

exit 0
