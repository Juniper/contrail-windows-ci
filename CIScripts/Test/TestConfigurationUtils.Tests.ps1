
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1

Describe "Select-CorrectNetIPInterface unit tests" -Tags CI, Unit {
        It "AddressFamily is matching and SuffixOrigin is 'Dhcp'" {
            $TestResult = $MockedGetNetIPAddress | Select-CorrectNetIPInterface
            $TestResult | Should -eq $MockedGetNetIPAddress
        }

        It "AddressFamily is matching and SuffixOrigin is 'Manual'" {
            $MockedGetNetIPAddress.SuffixOrigin = "Dhcp"
            $TestResult = $MockedGetNetIPAddress | Select-CorrectNetIPInterface
            $TestResult | Should -eq $MockedGetNetIPAddress
        }

        It "AddressFamily isn't matching" {
            $MockedGetNetIPAddress.AddressFamily = "IPv6"
            $TestResult = $MockedGetNetIPAddress | Select-CorrectNetIPInterface
            $TestResult | Should BeNullOrEmpty
        }

        It "SuffixOrigin isn't matching" {
            $MockedGetNetIPAddress.SuffixOrigin = "Well-Known"
            $TestResult = $MockedGetNetIPAddress | Select-CorrectNetIPInterface
            $TestResult | Should BeNullOrEmpty
        }

        It "Both AddressFamily and SuffixOrigin aren't matching" {
            $MockedGetNetIPAddress.AddressFamily = "IPv6"
            $MockedGetNetIPAddress.SuffixOrigin = "Well-Known"
            
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
            SuffixOrigin = "Dhcp"
        }
    }
}