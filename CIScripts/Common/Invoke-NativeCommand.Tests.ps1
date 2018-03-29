Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile
)

. $PSScriptRoot/Init.ps1
. $PSScriptRoot/../Testenv/Testenv.ps1
. $PSScriptRoot/VMUtils.ps1

. $PSScriptRoot/Invoke-NativeCommand.ps1


$Testbed = (Read-TestbedsConfig -Path $TestenvConfFile)[0]
$Sessions = New-RemoteSessions -VMs $Testbed
$Session = $Sessions[0]

Describe "Invoke-NativeCommand" {
    BeforeAll {
        Mock Write-Host {
            param([Parameter(ValueFromPipeline = $true)] $Object)
            $Script:WriteHostOutput += $Object
        }

        function Get-WriteHostOutput {
            $Script:WriteHostOutput
        }
    }

    BeforeEach {
        $Script:WriteHostOutput = @()
    }

    Context "Examples" {
        It "works on a simple case" {
            Invoke-NativeCommand { whoami.exe }
            Get-WriteHostOutput | Should BeLike '*\*'
        }

        It "can be used on remote session" {
            Invoke-NativeCommand -Session $Session { whoami.exe }
            Get-WriteHostOutput | Should BeLike "*\$( $Testbed.Username )"
        }

        It "can capture the exitcode" {
            $Command = Invoke-NativeCommand -AllowNonZero { whoami.exe /invalid_parameter }
            $Command.ExitCode | Should BeGreaterThan 0
        }

        It "can capture the output" {
            $Command = Invoke-NativeCommand -CaptureOutput { whoami.exe }
            $Command.Output | Should BeLike '*\*'
        }
    }

    Context "Local machine" {
        It "works on a simple case" {
            Invoke-NativeCommand { whoami.exe }
            Get-WriteHostOutput | Should BeLike '*\*'
        }

        It "can accept the scriptblock also as an explicit parameter" {
            Invoke-NativeCommand -CaptureOutput -ScriptBlock { whoami.exe }
        }

        It "throws on failed command" {
            { Invoke-NativeCommand { whoami.exe /invalid_parameter } } | Should Throw
        }

        It "throws on nonexisting command" {
            { Invoke-NativeCommand { asdfkljasdsdf.exe } } | Should Throw
        }

        It "captures the exitcode of successful command" {
            $Result = Invoke-NativeCommand -AllowNonZero { whoami.exe }
            $Result.ExitCode | Should Be 0
        }

        It "captures the exitcode a failed command" {
            (Invoke-NativeCommand -AllowNonZero { whoami.exe /invalid }).ExitCode | Should Not Be 0
        }

        It "can capture the output of a command" {
            (Invoke-NativeCommand -CaptureOutput { whoami.exe }).Output | Should BeLike '*\*'
        }

        It "can capture multiline output" {
            (Invoke-NativeCommand -CaptureOutput { whoami.exe /? }).Output.Count | Should BeGreaterThan 1
        }

        It "does not capture the output by default" {
            Invoke-NativeCommand { whoami.exe } | Should BeNullOrEmpty
        }

        It "can use variables it scriptblock" {
            $Command = "whoami.exe"
            (Invoke-NativeCommand -CaptureOutput -AllowNonZero { & $Command }).ExitCode | Should Be 0
        }

        It "preserves the ErrorActionPreference" {
            $ErrorActionPreference = "Stop"
            Invoke-NativeCommand -CaptureOutput { whoami.exe } | Out-Null
            $ErrorActionPreference | Should Be "Stop"
        }
    }

    Context "Remote machine" {
        It "does not throw on successful command" {
            Invoke-NativeCommand -Session $Session { whoami.exe }
        }

        It "can accept the scriptblock also as an explicit parameter" {
            Invoke-NativeCommand -Session $Session -CaptureOutput -ScriptBlock { whoami.exe }
        }

        It "throws on failed command" {
            { Invoke-NativeCommand -Session $Session { whoami.exe /invalid_parameter } } | Should Throw
        }

        It "throws on nonexisting command" {
            { Invoke-NativeCommand -Session $Session { asdfkljasdsdf.exe } } | Should Throw
        }

        It "captures the exitcode of successful command" {
            $Result = Invoke-NativeCommand -Session $Session -AllowNonZero { whoami.exe }
            $Result.ExitCode | Should Be 0
        }

        It "captures the exitcode a failed command" {
            (Invoke-NativeCommand -Session $Session -AllowNonZero { whoami.exe /invalid }).ExitCode | Should Not Be 0
        }

        It "can capture the output of a command" {
            (Invoke-NativeCommand -Session $Session -CaptureOutput { whoami.exe }).Output | Should BeLike '*\*'
        }

        It "can capture multiline output" {
            (Invoke-NativeCommand -Session $Session -CaptureOutput { whoami.exe /? }).Output.Count | Should BeGreaterThan 1
        }

        It "does not capture the output by default" {
            Invoke-NativeCommand -Session $Session { whoami.exe } | Should BeNullOrEmpty
        }

        It "can use variables it scriptblock" {
            $Command = "whoami.exe"
            (Invoke-NativeCommand -Session $Session -CaptureOutput -AllowNonZero { & $Using:Command }).ExitCode | Should Be 0
        }

        It "preserves the ErrorActionPreference" {
            $OldEA = Invoke-Command -Session $Session { $ErrorActionPreference }
            Invoke-NativeCommand -Session $Session -CaptureOutput { whoami.exe } | Out-Null
            Invoke-Command -Session $Session { $ErrorActionPreference } | Should Be $OldEA
        }
    }
}