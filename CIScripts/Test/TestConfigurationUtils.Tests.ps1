. $PSScriptRoot\..\Common\Init.ps1
. $PSScriptRoot\TestConfigurationUtils.ps1

Describe "Select-ValidNetIPInterface unit tests" -Tags CI, Unit {
    It "Simple valid/invalid Get-NetIPAddress output" {
        $TestCases = @(
            @{ Case = @{ AddressFamily = "IPv4"; SuffixOrigin = @("Dhcp", "Manual") }; Valid = $true },
            @{ Case = @{ AddressFamily = "IPv4"; SuffixOrigin = @("WellKnown", "Link", "Random") }; Valid = $false },
            @{ Case = @{ AddressFamily = "IPv6"; SuffixOrigin = @("Dhcp", "Manual") }; Valid = $false },
            @{ Case = @{ AddressFamily = "IPv6"; SuffixOrigin = @("WellKnown", "Link", "Random") }; Valid = $false }
        )

        foreach ($TestCase in $TestCases) {
            $TestResult = $TestCase.Case | Select-ValidNetIPInterface
            if ($( $TestCase.Valid )) {
                $TestResult | Should Be $TestCase.Case
            }
            else {
                $TestResult | Should BeNullOrEmpty
            }
        }
    }

    It "Pass valid/invalid object combinations into pipeline" {
        $InvalidGetNetIPAddress = @{
            AddressFamily = "IPv4";
            SuffixOrigin = @("WellKnown", "Link", "Random")
        }
        $ValidGetNetIPAddress = @{
            AddressFamily = "IPv4";
            SuffixOrigin = @("Dhcp", "Manual")
        }

        $TestCases = @(
            @{ Case = @($( $InvalidGetNetIPAddress ), $( $ValidGetNetIPAddress )); Valid = $true },
            @{ Case = @($( $ValidGetNetIPAddress ), $( $InvalidGetNetIPAddress )); Valid = $true },
            @{ Case = @($( $InvalidGetNetIPAddress ), $( $InvalidGetNetIPAddress )); Valid = $false }
        )

        foreach ($TestCase in $TestCases) {
            $TestResult = $TestCase.Case | Select-ValidNetIPInterface
            if ($( $TestCase.Valid )) {
                $TestResult | Should Be $ValidGetNetIPAddress
            }
            else {
                $TestResult | Should BeNullOrEmpty
            }
        }
    }
}
