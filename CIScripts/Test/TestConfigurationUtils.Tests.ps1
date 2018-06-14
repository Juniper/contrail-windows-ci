. $PSScriptRoot\TestConfigurationUtils.ps1

function Select-ValidNetIPInterface {
    Param ([parameter(Mandatory=$true, ValueFromPipeline=$true)]$GetIPAddressOutput)

    Process { Invoke-Expression "$SelectValidNetIPInterfaceBody" }
}

Describe "Select-ValidNetIPInterface unit tests" -Tags CI, Unit {
        It "Both AddressFamily and SuffixOrigin match values in Select-ValidNetIPInterface" {
            $MockedGetNetIPAddress = @{
                AddressFamily = "IPv4";
                SuffixOrigin = @("Dhcp", "Manual")
            }

            $TestResult = $MockedGetNetIPAddress | Select-ValidNetIPInterface
            $TestResult | Should Be $MockedGetNetIPAddress
        }

        It "AddressFamily isn't matching" {
            $MockedGetNetIPAddress = @{
                AddressFamily = "IPv6";
                SuffixOrigin = @("Dhcp", "Manual")
            }

            $TestResult = $MockedGetNetIPAddress | Select-ValidNetIPInterface
            $TestResult | Should BeNullOrEmpty
        }

        It "SuffixOrigin isn't matching" {
            $MockedGetNetIPAddress = @{
                AddressFamily = "IPv4";
                SuffixOrigin = @("WellKnown", "Link", "Random")
            }

            $TestResult = $MockedGetNetIPAddress | Select-ValidNetIPInterface
            $TestResult | Should BeNullOrEmpty
        }

        It "Both AddressFamily and SuffixOrigin do not match" {
            $MockedGetNetIPAddress = @{
                AddressFamily = "IPv6";
                SuffixOrigin = @("WellKnown", "Link", "Random")
            }
            
            $TestResult = $MockedGetNetIPAddress | Select-ValidNetIPInterface
            $TestResult  | Should BeNullOrEmpty
        }

        It "Both AddressFamily and SuffixOrigin are empty strings" {
            $MockedGetNetIPAddress = @{
                AddressFamily = "";
                SuffixOrigin = ""
            }

            $TestResult = $MockedGetNetIPAddress | Select-ValidNetIPInterface
            $TestResult | Should BeNullOrEmpty
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

            $MockedGetNetIPAddress = @($InvalidGetNetIPAddress, $ValidGetNetIPAddress)
            $TestResult = $MockedGetNetIPAddress | Select-ValidNetIPInterface
            $TestResult | Should Be $ValidGetNetIPAddress

            $MockedGetNetIPAddress = $InvalidGetNetIPAddress, $ValidGetNetIPAddress
            $TestResult = $MockedGetNetIPAddress | Select-ValidNetIPInterface
            $TestResult | Should Be $ValidGetNetIPAddress

            $MockedGetNetIPAddress = @($ValidGetNetIPAddress, $InvalidGetNetIPAddress)
            $TestResult = $MockedGetNetIPAddress | Select-ValidNetIPInterface
            $TestResult | Should Be $ValidGetNetIPAddress

            $MockedGetNetIPAddress = $InvalidGetNetIPAddress, $InvalidGetNetIPAddress
            $TestResult = $MockedGetNetIPAddress | Select-ValidNetIPInterface
            $TestResult | Should BeNullOrEmpty
        }
}
