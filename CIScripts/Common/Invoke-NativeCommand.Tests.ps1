. $PSScriptRoot/Invoke-NativeCommand.ps1

Describe "Invoke-NativeCommand" {
    Context "Local machine" {
        It "does not throw on successful command" {
            { Invoke-NativeCommand { whoami.exe } } | Should Not Throw
        }

        It "throws on failed command" {
            { Invoke-NativeCommand { whoami.exe /invalid_parameter } } | Should Throw
        }

        It "captures the exitcode of successful command" {
            (Invoke-NativeCommand -AllowNonZero { whoami.exe })[-1] | Should Be 0
        }

        It "captures the exitcode a failed command" {
            (Invoke-NativeCommand -AllowNonZero { whoami.exe /invalid })[-1] | Should Not Be 0
        }

        It "can capture the output of a command" {
            Invoke-NativeCommand { whoami.exe } | Should BeLike '*\*'
        }
    }
}