Param (
    [Parameter(Mandatory = $false)] [string] $TestenvConfFile,
    [Parameter(Mandatory = $false)] [string] $LogDir = "pesterLogs",
    [Parameter(Mandatory = $false)] [bool] $PrepareEnv = $true,
    [Parameter(ValueFromRemainingArguments = $true)] $UnusedParams
)

. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

Test-WithRetries 3 {
    Describe "Dummy test" -Tag "Smoke" {
        BeforeAll {
            Initialize-PesterLogger -OutDir $LogDir
        }

        It "ET goes home" {
            Write-Log "OK This is epic flake"
            $true | Should -BeTrue
        }
    }
}
