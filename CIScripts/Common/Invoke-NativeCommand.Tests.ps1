. $PSScriptRoot/Init.ps1
. $PSScriptRoot/Invoke-NativeCommand.ps1

Describe "Invoke-NativeCommand" {
    Context "Local machine" {
        It "does not throw on successful command" {
            { Invoke-NativeCommand { whoami.exe } } | Should Not Throw
        }

        It "can accept the scriptblock also as an explicit parameter" {
            { Invoke-NativeCommand -CaptureOutput -ScriptBlock { whoami.exe } } | Should Not Throw
        }

        It "throws on failed command" {
            { Invoke-NativeCommand { whoami.exe /invalid_parameter } } | Should Throw
        }

        It "throws on nonexisting command" {
            { Invoke-NativeCommand { asdfkljasdsdf.exe } } | Should Throw
        }

        It "captures the exitcode of successful command" {
            (Invoke-NativeCommand -AllowNonZero { whoami.exe }).ExitCode | Should Be 0
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
    }
}