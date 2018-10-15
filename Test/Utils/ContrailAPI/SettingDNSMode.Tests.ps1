Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\DNSServer.ps1
. $PSScriptRoot\SettingDNSMode.ps1
. $PSScriptRoot\..\ContrailUtils.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1

# TODO: Those tests run on working Controller.
#       Most probably they need to be rewrote
#       to use some fake.
# NOTE: Because of the above they should not be run automatically
Describe 'Configure DNS API' -Tags CI, Systest {
    BeforeAll {
        $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
        $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "ContrailUrl",
            Justification="It's actually used."
        )]
        $ContrailUrl = $ControllerConfig.RestApiUrl()

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "AuthToken",
            Justification="It's actually used."
        )]
        $AuthToken = Get-AccessTokenFromKeystone `
            -AuthUrl $OpenStackConfig.AuthUrl() `
            -Username $OpenStackConfig.Username `
            -Password $OpenStackConfig.Password `
            -Tenant $OpenStackConfig.Project
    }

    Context 'Setting DNS modes' {
        It 'throws when wrong dns mode specified' {
            {
                Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                    -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
                    -DNSMode 'wrongdnsmode'
            } | Should -Throw
        }

        Context 'mode - none' {
            It 'can set DNS mode to none' {
                {
                    Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                        -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
                        -DNSMode 'none'
                } | Should -Not -Throw
            }
        }

        Context 'mode - default' {
            It 'can set DNS mode to default' {
                {
                    Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                        -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
                        -DNSMode 'default-dns-server'
                } | Should -Not -Throw
            }
        }

        Context 'mode - tenant' {
            It 'can set DNS mode to tenant without DNS servers' {
                {
                    Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                        -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
                        -DNSMode 'tenant-dns-server'
                } | Should -Not -Throw
            }

            It 'can set DNS mode to tenant with DNS servers' {
                {
                    Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                        -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
                        -DNSMode 'tenant-dns-server' -Options ([TenantDNSOptions]::New(@("1.1.1.1", "2.2.2.2")))
                } | Should -Not -Throw
            }
        }

        Context 'mode - virtual' {
            It 'can set DNS mode to virtual' {
                $ServerUUID = Add-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                    -DNSServerName "CreatedByPS1ScriptForIpam"

                {
                    Try {
                        Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                            -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
                            -DNSMode 'virtual-dns-server' -Options ([VirtualDNSOptions]::New("CreatedByPS1ScriptForIpam"))
                    } Finally {
                        Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSServerUuid $ServerUUID -Force
                    }
                } | Should -Not -Throw
            }

            It 'throws when no virtual DNS server specified in virtual DNS mode' {
                {
                    Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                        -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
                        -DNSMode 'virtual-dns-server'
                } | Should -Throw
            }
        }
    }
}
