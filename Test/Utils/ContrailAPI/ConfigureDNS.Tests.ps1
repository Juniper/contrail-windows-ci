Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile = "C:\scripts\configurations\test_configuration.yaml",
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\ConfigureDNS.ps1
. $PSScriptRoot\..\ContrailUtils.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1


# TODO: Those tests run on working Controller.
#       Most probably they need to be rewrote
#       to use some fake.
# NOTE: Because of the above they should not be run automatically
Describe 'Configure DNS API' {
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

    It 'adds and removes "empty" contrail DNS server' {
        $ServerUUID = Add-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -DNSServerName "CreatedByPS1Script"
        Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSServerUuid $ServerUUID
    }

    It 'adds and removes DNS server records' {
        $ServerUUID = Add-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -DNSServerName "CreatedByPS1Script"

        $Record1Data = [VirtualDNSRecordData]::new("host1", "1.2.3.4", "A")
        $Record1UUID = Add-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -DNSServerName "CreatedByPS1Script" -VirtualDNSRecordData $Record1Data

        $Record2Data = [VirtualDNSRecordData]::new("host2", "1.2.3.5", "A")
        $Record2UUID = Add-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -DNSServerName "CreatedByPS1Script" -VirtualDNSRecordData $Record2Data

        Remove-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSRecordUuid $Record1UUID
        Remove-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSRecordUuid $Record2UUID

        Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSServerUuid $ServerUUID
    }

    It 'breaks when wrong dns mode specified' {
        { Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
            -DNSMode 'wrongdnsmode' } | Should -Throw
    }

    It 'sets DNS mode to none' {
        Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
            -DNSMode 'none'
    }

    It 'sets DNS mode to default' {
        Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
            -DNSMode 'default-dns-server'
    }

    It 'sets DNS mode to tenant without DNS servers' {
        Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
            -DNSMode 'tenant-dns-server'
    }

    It 'sets DNS mode to tenant with DNS servers' {
        Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
            -DNSMode 'tenant-dns-server' -TenantServersIPAddresses @("1.1.1.1", "2.2.2.2")
    }

    It 'sets DNS mode to virtual' {
        $ServerUUID = Add-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -DNSServerName "CreatedByPS1Script"

        Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
            -DNSMode 'virtual-dns-server' -VirtualServerName "CreatedByPS1Script"

        Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken -DNSServerUuid $ServerUUID -Force
    }

    It 'breaks when no virtual DNS server specified in virtual DNS mode' {
        { Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
            -DNSMode 'virtual-dns-server' } | Should -Throw
    }

    It 'needs -Force switch to remove not "empty" DNS Server' {
        $ServerUUID = Add-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -DNSServerName "CreatedByPS1Script"

        $Record1Data = [VirtualDNSRecordData]::new("host1", "1.2.3.4", "A")
        Add-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -DNSServerName "CreatedByPS1Script" -VirtualDNSRecordData $Record1Data

        $Record2Data = [VirtualDNSRecordData]::new("host2", "1.2.3.5", "A")
        Add-ContrailDNSRecord -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -DNSServerName "CreatedByPS1Script" -VirtualDNSRecordData $Record2Data

        Set-IpamDNSMode -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -IpamFQName @("default-domain", "default-project", "default-network-ipam") `
            -DNSMode 'virtual-dns-server' -VirtualServerName "CreatedByPS1Script"

        { Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -DNSServerUuid $ServerUUID } | Should -Throw

        Remove-ContrailDNSServer -ContrailUrl $ContrailUrl -AuthToken $AuthToken `
            -DNSServerUuid $ServerUUID -Force
    }
}
