Param (
    [Parameter(Mandatory = $false)] [string] $TestenvConfFile,
    [Parameter(ValueFromRemainingArguments = $true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Common\Init.ps1

. $PSScriptRoot\..\..\Utils\Testenv\Configs.ps1
. $PSScriptRoot\..\..\Utils\Testenv\Testbed.ps1

. $PSScriptRoot\..\..\Utils\ComputeNode\Installation.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1

Describe 'vTest scenarios' -Tag 'Smoke' {
    It 'passes all vtest scenarios' {
        $VMSwitchName = $SystemConfig.VMSwitchName()
        {
            Invoke-Command -Session $Session -ScriptBlock {
                Push-Location C:\Artifacts\
                .\vtest\all_tests_run.ps1 -VMSwitchName $Using:VMSwitchName `
                    -TestsFolder vtest\tests
                Pop-Location
            }
        } | Should Not Throw
    }

    BeforeAll {
        $Sessions = New-RemoteSessions -VMs ([Testbed]::LoadFromFile($TestenvConfFile))
        $Session = $Sessions[0]

        $SystemConfig = [SystemConfig]::LoadFromFile($TestenvConfFile)

        Install-Extension -Session $Session
        Install-Utils -Session $Session
        Enable-VRouterExtension -Session $Session -SystemConfig $SystemConfig
    }

    AfterAll {
        if (-not (Get-Variable Sessions -ErrorAction SilentlyContinue)) { return }
        Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig
        Uninstall-Utils -Session $Session
        Uninstall-Extension -Session $Session
        Remove-PSSession $Sessions
    }
}
