Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs",
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Common\Invoke-UntilSucceeds.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Init.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1

. $PSScriptRoot\..\..\Utils\ComputeNode\Installation.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Configuration.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Service.ps1

. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

Describe "CNM Plugin service" {
    Context "disabling"  {
        It "is disabled" -Pending {
            Get-CNMPluginServiceStatus -Session $Session | Should Be "Stopped"
        }

        It "does not restart" -Pending {
            Consistently {
                Get-CNMPluginServiceStatus -Session $Session | Should Be "Stopped"
            } -Duration 3
        }

        BeforeEach {
            Enable-CNMPluginService -Session $Session
            Invoke-UntilSucceeds {
                (Get-CNMPluginServiceStatus -Session $Session) -eq 'Running'
            } -Duration 30
            Disable-CNMPluginService -Session $Session
        }
    }
    Context "Agent is not running" {
        It "Unimplemented" -Pending {}
    }
    Context "CNM Plugin service removal works correctly" {
        It "Unimplemented" -Pending {}
    }

    BeforeEach {
        Initialize-ComputeServices -Session $Session `
            -SystemConfig $SystemConfig `
            -OpenStackConfig $OpenStackConfig `
            -ControllerConfig $ControllerConfig

        if ((Get-CNMPluginServiceStatus -Session $Session) -eq "Running") {
            Disable-CNMPluginService -Session $Session
        }
    }

    AfterEach {
        try {
            Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig
        } finally {
            Merge-Logs -LogSources (New-FileLogSource -Path (Get-ComputeLogsPath) -Sessions $Session)
        }
    }

    BeforeAll {
        $Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
        $Session = $Sessions[0]

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "",
            Justification="Analyzer doesn't understand relation of Pester blocks"
        )]
        $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "",
            Justification="Analyzer doesn't understand relation of Pester blocks"
        )]
        $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "",
            Justification="Analyzer doesn't understand relation of Pester blocks"
        )]
        $SystemConfig = Read-SystemConfig -Path $TestenvConfFile

        Initialize-PesterLogger -OutDir $LogDir

        Install-Components -Session $Session
    }

    AfterAll {
        if (-not (Get-Variable Sessions -ErrorAction SilentlyContinue)) { return }
        Uninstall-Components -Session $Session
        Remove-PSSession $Sessions
    }
}
