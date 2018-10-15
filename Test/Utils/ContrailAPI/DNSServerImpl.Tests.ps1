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
            "DNSServer",
            Justification="It's actually used."
        )]
        $DNSServer = [DNSServer]::New($ContrailNM)
    }

    Context 'DNS server creation and removal' {

        It 'can add and remove not attached to ipam DNS server without records' {
            {
                $ServerUUID = $DNSServer.AddContrailDNSServer("CreatedByPS1ScriptEmpty")
                $DNSServer.RemoveContrailDNSServer($ServerUUID, $true)
            } | Should -Not -Throw
        }

        It 'can add and remove DNS server records' {
            $ServerUUID = $DNSServer.AddContrailDNSServer("CreatedByPS1Script")
            {
                Try
                {
                    $Record1UUID = $DNSServer.AddContrailDNSRecord("CreatedByPS1Script", "host1", "1.2.3.4")
                    $Record2UUID = $DNSServer.AddContrailDNSRecord("CreatedByPS1Script", "host2", "1.2.3.5")

                    $DNSServer.RemoveContrailDNSRecord($Record1UUID)
                    $DNSServer.RemoveContrailDNSRecord($Record2UUID)
                }
                Finally
                {
                    $DNSServer.RemoveContrailDNSServer($ServerUUID, $true)
                }
            } | Should -Not -Throw
        }

        It 'needs -Force switch to remove attached to ipam DNS Server with records' {
            $ServerUUID = $DNSServer.AddContrailDNSServer("CreatedByPS1ScriptForce")

            $DNSServer.AddContrailDNSRecord("CreatedByPS1ScriptForce", "host1", "1.2.3.4")
            $DNSServer.AddContrailDNSRecord("CreatedByPS1ScriptForce", "host2", "1.2.3.5")

            $NetworkIPAM = [NetworkIPAM]::New($ContrailNM)
            $NetworkIPAM.SetIpamDNSMode($IPAMFQName, 'virtual-dns-server', ([VirtualDNSOptions]::New("CreatedByPS1ScriptForce")))

            {
                $DNSServer.RemoveContrailDNSServer($ServerUUID, $false)
            } | Should -Throw

            {
                $DNSServer.RemoveContrailDNSServer($ServerUUID, $true)
            } | Should -Not -Throw
        }
    }
}
