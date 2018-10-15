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

    Context 'DNS server creation and removal' {

        It 'can add and remove not attached to ipam DNS server without records' {
            {
                $ServerUUID = Add-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                    -DNSServerName "CreatedByPS1ScriptEmpty"
                Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                    -DNSServerUuid $ServerUUID
            } | Should -Not -Throw
        }

        It 'can add and remove DNS server records' {
            $ServerUUID = Add-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                -DNSServerName "CreatedByPS1Script"

            {
                Try {
                    $Record1Data = [VirtualDNSRecordData]::new("host1", "1.2.3.4", "A")
                    $Record1UUID = Add-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                        -DNSServerName "CreatedByPS1Script" -VirtualDNSRecordData $Record1Data

                    $Record2Data = [VirtualDNSRecordData]::new("host2", "1.2.3.5", "A")
                    $Record2UUID = Add-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                        -DNSServerName "CreatedByPS1Script" -VirtualDNSRecordData $Record2Data

                    Remove-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSRecordUuid $Record1UUID
                    Remove-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSRecordUuid $Record2UUID
                } Finally {
                    Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSServerUuid $ServerUUID -Force
                }
            } | Should -Not -Throw
        }

        It 'can add and remove DNS server records by string' {
            $ServerUUID = Add-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                -DNSServerName "CreatedByPS1ScriptString"

            {
                Try {
                    $Record1UUID = Add-ContrailDNSRecordByStrings -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                        -DNSServerName "CreatedByPS1ScriptString" -HostName "host1string" -HostIP "1.2.3.4"

                    $Record2UUID = Add-ContrailDNSRecordByStrings -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                        -DNSServerName "CreatedByPS1ScriptString" -HostName "host2string" -HostIP "1.2.3.5"

                    Remove-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSRecordUuid $Record1UUID
                    Remove-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSRecordUuid $Record2UUID
                } Finally {
                    Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSServerUuid $ServerUUID -Force
                }
            } | Should -Not -Throw
        }

        It 'needs -Force switch to remove attached to ipam DNS Server with records' {
            $ServerUUID = Add-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                -DNSServerName "CreatedByPS1ScriptForce"

            $Record1Data = [VirtualDNSRecordData]::new("host1", "1.2.3.4", "A")
            Add-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                -DNSServerName "CreatedByPS1ScriptForce" -VirtualDNSRecordData $Record1Data

            $Record2Data = [VirtualDNSRecordData]::new("host2", "1.2.3.5", "A")
            Add-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                -DNSServerName "CreatedByPS1ScriptForce" -VirtualDNSRecordData $Record2Data

            Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
                -DNSMode 'virtual-dns-server' -Options ([VirtualDNSOptions]::New("CreatedByPS1ScriptForce"))

            {
                Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                    -DNSServerUuid $ServerUUID
            } | Should -Throw

            {
                Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
                    -DNSServerUuid $ServerUUID -Force
            } | Should -Not -Throw
        }
    }
}
