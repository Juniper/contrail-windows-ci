
. $PSScriptRoot\TestConfigurationUtils.ps1

Describe "Select-CorrectNetIPInterface unit tests" -Tags CI, Unit {
        It "Both AddressFamily and SuffixOrigin match values in Select-CorrectNetIPInterface" {
            $TestResult = $MockedGetNetIPAddress | Select-CorrectNetIPInterface
            $TestResult | Should -eq $MockedGetNetIPAddress
        }

        It "AddressFamily isn't matching" {
            $MockedGetNetIPAddress.AddressFamily = "IPv6"
            $TestResult = $MockedGetNetIPAddress | Select-CorrectNetIPInterface
            $TestResult | Should BeNullOrEmpty
        }

        It "SuffixOrigin isn't matching" {
            $MockedGetNetIPAddress.SuffixOrigin = "WellKnown", "Link", "Random"
            $TestResult = $MockedGetNetIPAddress | Select-CorrectNetIPInterface
            $TestResult | Should BeNullOrEmpty
        }

        It "Both AddressFamily and SuffixOrigin do not match" {
            $MockedGetNetIPAddress.AddressFamily = "IPv6"
            $MockedGetNetIPAddress.SuffixOrigin = "WellKnown", "Link", "Random"
            
            $TestResult = $MockedGetNetIPAddress | Select-CorrectNetIPInterface
            $TestResult  | Should BeNullOrEmpty
        }

        It "Both AddressFamily and SuffixOrigin are empty strings" {
            $MockedGetNetIPAddress.AddressFamily = ""
            $MockedGetNetIPAddress.SuffixOrigin = ""

            $TestResult = $MockedGetNetIPAddress | Select-CorrectNetIPInterface
            $TestResult | Should BeNullOrEmpty
        }

    BeforeEach {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "",
            Justification="Analyzer doesn't understand relation of Pester blocks"
        )]
        $MockedGetNetIPAddress = @{
            AddressFamily = "IPv4";
            SuffixOrigin = "Dhcp", "Manual"
        }
    }
}
