Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\DNSServer.ps1
. $PSScriptRoot\SettingDNSMode.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1

# TODO: Those tests run on working Controller.
#       Most probably they need to be rewrote
#       to use some fake.
Describe 'Configure DNS Class API' -Tags CI, Systest {
    BeforeAll {
        $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
        $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
        $ContrailNM = [ContrailNetworkManager]::New($OpenStackConfig, $ControllerConfig)

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "NetworkIPAM",
            Justification="It's actually used."
        )]
        $NetworkIPAM = [NetworkIPAM]::New($ContrailNM)
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "IPAMFQName",
            Justification="It's actually used."
        )]
        $IPAMFQName = @("default-domain", "default-project", "default-network-ipam")
    }

    Context 'Setting DNS modes' {
        It 'throws when wrong dns mode specified' {
            {
                $NetworkIPAM.SetIpamDNSMode($IPAMFQName, 'wrongdnsmode', $null)
            } | Should -Throw
        }

        Context 'mode - none' {
            It 'can set DNS mode to none' {
                {
                    $NetworkIPAM.SetIpamDNSMode($IPAMFQName, 'none', $null)
                } | Should -Not -Throw
            }
        }

        Context 'mode - default' {
            It 'can set DNS mode to default' {
                {
                    $NetworkIPAM.SetIpamDNSMode($IPAMFQName, 'default-dns-server', $null)
                } | Should -Not -Throw
            }
        }

        Context 'mode - tenant' {
            It 'throws when no DNS server specified' {
                {
                    $NetworkIPAM.SetIpamDNSMode($IPAMFQName, 'tenant-dns-server', $null)
                } | Should -Throw
            }

            It 'can set DNS mode to tenant with DNS servers' {
                {
                    $NetworkIPAM.SetIpamDNSMode($IPAMFQName, 'tenant-dns-server', ([TenantDNSOptions]::New(@("1.1.1.1", "2.2.2.2"))))
                } | Should -Not -Throw
            }
        }

        Context 'mode - virtual' {
            It 'throws when no virtual DNS server specified in virtual DNS mode' {
                {
                    $NetworkIPAM.SetIpamDNSMode($IPAMFQName, 'virtual-dns-server', $null)
                } | Should -Throw
            }

            It 'can set DNS mode to virtual' {
                $DNSServer = [DNSServer]::New($ContrailNM)
                $ServerUUID = $ServerUUID = $DNSServer.AddContrailDNSServer("CreatedByPS1ScriptForIpam")
                {
                    Try {
                        $NetworkIPAM.SetIpamDNSMode($IPAMFQName, 'virtual-dns-server', ([VirtualDNSOptions]::New("CreatedByPS1ScriptForIpam")))
                    } Finally {
                        $DNSServer.RemoveContrailDNSServer($ServerUUID, $true)
                    }
                } | Should -Not -Throw
            }
        }
    }
}
