Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\DNSServerRepo.ps1
. $PSScriptRoot\IPAMRepo.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1

# TODO: Those tests run on working Controller.
#       Most probably they need to be rewrote
#       to use some fake.
Describe 'Configure DNS Class API' -Tags CI, Systest {
    BeforeAll {
        $TestenvConfFile = "C:\scripts\configurations\test_configuration.yaml"
        $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
        $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
        $ContrailNM = [ContrailNetworkManager]::New($OpenStackConfig, $ControllerConfig)

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "DNSServer",
            Justification="It's actually used."
        )]
        $DNSServerRepo = [DNSServerRepo]::New($ContrailNM)
    }

    Context 'DNS server creation and removal' {

        It 'can add and remove not attached to ipam DNS server without records' {
            {
                $Server = [DNSServer]::New("CreatedByPS1ScriptEmpty")
                $DNSServerRepo.AddContrailDNSServer($Server)
                $DNSServerRepo.RemoveContrailDNSServer($Server, $false)
            } | Should -Not -Throw
        }

        It 'can remove DNS server by name' {
            {
                $DNSServerRepo.AddContrailDNSServer([DNSServer]::New("CreatedByPS1ScriptByName"))
                $DNSServerRepo.RemoveContrailDNSServer([DNSServer]::New("CreatedByPS1ScriptByName"), $false)
            } | Should -Not -Throw
        }

        It 'can add and remove DNS server records' {
            $Server = [DNSServer]::New("CreatedByPS1ScriptRecords")
            $DNSServerRepo.AddContrailDNSServer($Server)
            {
                Try
                {
                    $Record1 = [DNSRecord]::New("host1", "1.2.3.4", "A", $Server.GetFQName())
                    $Record2 = [DNSRecord]::New("host2", "1.2.3.5", "A", $Server.GetFQName())

                    $DNSServerRepo.AddContrailDNSRecord($Record1)
                    $DNSServerRepo.AddContrailDNSRecord($Record2)

                    $DNSServerRepo.RemoveContrailDNSRecord($Record1)
                    $DNSServerRepo.RemoveContrailDNSRecord($Record2)
                }
                Finally
                {
                    $DNSServerRepo.RemoveContrailDNSServer($Server, $true)
                }
            } | Should -Not -Throw
        }

        # Until we will be able to determine record internal name,
        # this test should be pending
        It 'can remove DNS server records by name' -Pending {
            $Server = [DNSServer]::New("CreatedByPS1ScriptRecordsByName")
            $DNSServerRepo.AddContrailDNSServer($Server)
            {
                Try
                {

                    $DNSServerRepo.AddContrailDNSRecord([DNSRecord]::New("host1", "1.2.3.4", "A", $Server.GetFQName()))
                    $DNSServerRepo.AddContrailDNSRecord([DNSRecord]::New("host2", "1.2.3.5", "A", $Server.GetFQName()))

                    $DNSServerRepo.RemoveContrailDNSRecord([DNSRecord]::New("host1", "1.2.3.4", "A", $Server.GetFQName()))
                    $DNSServerRepo.RemoveContrailDNSRecord([DNSRecord]::New("host2", "1.2.3.5", "A", $Server.GetFQName()))

                    $DNSServerRepo.RemoveContrailDNSServer($Server, $false)
                }
                Catch
                {
                    $DNSServerRepo.RemoveContrailDNSServer($Server, $true)
                    Throw
                }
            } | Should -Not -Throw
        }

        It 'needs -Force switch to remove attached to ipam DNS Server with records' {
            $Server = [DNSServer]::New("CreatedByPS1ScriptForce")
            $Record1 = [DNSRecord]::New("host1", "1.2.3.4", "A", $Server.GetFQName())
            $Record2 = [DNSRecord]::New("host2", "1.2.3.5", "A", $Server.GetFQName())

            $DNSServerRepo.AddContrailDNSServer($Server)
            $DNSServerRepo.AddContrailDNSRecord($Record1)
            $DNSServerRepo.AddContrailDNSRecord($Record2)

            $IPAMRepo = [IPAMRepo]::New($ContrailNM)
            $IPAM = [IPAM]::New()
            $IPAM.DNSSettings = [VirtualDNSSettings]::New($Server.GetFQName())
            $IPAMRepo.SetIpamDNSMode($IPAM)

            {
                $DNSServerRepo.RemoveContrailDNSServer($Server, $false)
            } | Should -Throw

            {
                $DNSServerRepo.RemoveContrailDNSServer($Server, $true)
            } | Should -Not -Throw
        }
    }
}
