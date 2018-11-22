Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs",
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1

. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\Utils\WinContainers\Containers.ps1
. $PSScriptRoot\..\..\Utils\Network\Connectivity.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Initialize.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Configuration.ps1
. $PSScriptRoot\..\..\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\..\Utils\DockerNetwork\DockerNetwork.ps1
. $PSScriptRoot\..\..\Utils\MultiNode\ContrailMultiNodeProvisioning.ps1

$PolicyName = "passallpolicy"

$ClientNetworkSubnet = [SubnetConfiguration]::new(
    "10.1.1.0",
    24,
    "10.1.1.1",
    "10.1.1.11",
    "10.1.1.100"
)
$ClientNetwork = [Network]::New("network1", $ClientNetworkSubnet)

$ServerNetworkSubnet = [SubnetConfiguration]::new(
    "10.2.2.0",
    24,
    "10.2.2.1",
    "10.2.2.11",
    "10.2.2.100"
)
$ServerNetwork = [Network]::New("network2", $ServerNetworkSubnet)

$ServerFloatingIpPoolName = "pool"
$ServerFloatingIpName = "fip"
$ServerFloatingIpAddress = "10.2.2.10"

$ContainerImage = "microsoft/windowsservercore"
$ContainerClientID = "fip-client"
$ContainerServer1ID = "fip-server1"

Describe "Floating IP" {
    Context "Multinode" {
        Context "2 networks" {
            It "ICMP works" {
                Test-Ping `
                    -Session $MultiNode.Sessions[0] `
                    -SrcContainerName $ContainerClientID `
                    -DstIP $ServerFloatingIpAddress | Should Be 0
            }

            BeforeAll {
                Write-Log "Creating network policy: $PolicyName"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailPolicy",
                    Justification="It's actually used."
                )]
                $ContrailPolicy = Add-ContrailPassAllPolicy `
                    -API $MultiNode.NM `
                    -Name $PolicyName `
                    -TenantName $MultiNode.NM.DefaultTenantName

                Write-Log "Creating virtual network: $ClientNetwork.Name"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailClientNetwork",
                    Justification="It's actually used."
                )]
                $ContrailClientNetwork = Add-OrReplaceNetwork `
                    -API $MultiNode.NM `
                    -TenantName $MultiNode.NM.DefaultTenantName `
                    -Name $ClientNetwork.Name `
                    -SubnetConfig $ClientNetwork.Subnet

                Write-Log "Creating virtual network: $ServerNetwork.Name"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailServerNetwork",
                    Justification="It's actually used."
                )]
                $ContrailServerNetwork = Add-OrReplaceNetwork `
                    -API $MultiNode.NM `
                    -TenantName $MultiNode.NM.DefaultTenantName `
                    -Name $ServerNetwork.Name `
                    -SubnetConfig $ServerNetwork.Subnet

                Write-Log "Creating floating IP pool: $ServerFloatingIpPoolName"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailFloatingIpPool",
                    Justification="It's actually used."
                )]
                $ContrailFloatingIpPool = Add-ContrailFloatingIpPool `
                    -API $MultiNode.NM `
                    -TenantName $MultiNode.NM.DefaultTenantName `
                    -NetworkName $ServerNetwork.Name `
                    -PoolName $ServerFloatingIpPoolName

                Add-ContrailPolicyToNetwork `
                    -API $MultiNode.NM `
                    -PolicyUuid $ContrailPolicy `
                    -NetworkUuid $ContrailClientNetwork

                Add-ContrailPolicyToNetwork `
                    -API $MultiNode.NM `
                    -PolicyUuid $ContrailPolicy `
                    -NetworkUuid $ContrailServerNetwork
            }

            AfterAll {
                Write-Log "Deleting floating IP pool"
                if (Get-Variable ContrailFloatingIpPool -ErrorAction SilentlyContinue) {
                    Remove-ContrailFloatingIpPool `
                        -API $MultiNode.NM `
                        -PoolUuid $ContrailFloatingIpPool
                }

                Write-Log "Deleting virtual network"
                if (Get-Variable ContrailServerNetwork -ErrorAction SilentlyContinue) {
                    Remove-ContrailVirtualNetwork `
                        -API $MultiNode.NM `
                        -NetworkUuid $ContrailServerNetwork
                }

                Write-Log "Deleting virtual network"
                if (Get-Variable ContrailClientNetwork -ErrorAction SilentlyContinue) {
                    Remove-ContrailVirtualNetwork `
                        -API $MultiNode.NM `
                        -NetworkUuid $ContrailClientNetwork
                }

                Write-Log "Deleting network policy"
                if (Get-Variable ContrailPolicy -ErrorAction SilentlyContinue) {
                    Remove-ContrailPolicy `
                        -API $MultiNode.NM `
                        -Uuid $ContrailPolicy
                }
            }

            BeforeEach {
                $Networks = @($ClientNetwork, $ServerNetwork)
                foreach ($Session in $MultiNode.Sessions) {
                    Initialize-ComputeNode -Session $Session -Networks $Networks -Configs $MultiNode.Configs
                }

                Write-Log "Creating containers"
                Write-Log "Creating container: $ContainerClientID"
                New-Container `
                    -Session $MultiNode.Sessions[0] `
                    -NetworkName $ClientNetwork.Name `
                    -Name $ContainerClientID `
                    -Image $ContainerImage

                Write-Log "Creating containers"
                Write-Log "Creating container: $ContainerServer1ID"
                New-Container `
                    -Session $MultiNode.Sessions[1] `
                    -NetworkName $ServerNetwork.Name `
                    -Name $ContainerServer1ID `
                    -Image $ContainerImage

                Write-Log "Creating floating IP: $ServerFloatingIpPoolName"
                $ContrailFloatingIp = Add-ContrailFloatingIp `
                    -API $MultiNode.NM `
                    -PoolUuid $ContrailFloatingIpPool `
                    -IPName $ServerFloatingIpName `
                    -IPAddress $ServerFloatingIpAddress

                $PortFqNames = Get-ContrailVirtualNetworkPorts `
                    -API $MultiNode.NM `
                    -NetworkUuid $ContrailServerNetwork

                Set-ContrailFloatingIpPorts `
                    -API $MultiNode.NM `
                    -IpUuid $ContrailFloatingIp `
                    -PortFqNames $PortFqNames
            }

            AfterEach {
                Write-Log "Deleting floating IP"
                if (Get-Variable ContrailFloatingIp -ErrorAction SilentlyContinue) {
                    Remove-ContrailFloatingIp `
                        -API $MultiNode.NM `
                        -IpUuid $ContrailFloatingIp
                }

                $Sessions = $MultiNode.Sessions
                $SystemConfig = $MultiNode.Configs.System
                try {
                    Merge-Logs -LogSources (
                        (New-ContainerLogSource -Sessions $Sessions[0] -ContainerNames $ContainerClientID),
                        (New-ContainerLogSource -Sessions $Sessions[1] -ContainerNames $ContainerServer1ID)
                    )

                    Write-Log "Removing all containers"
                    Remove-AllContainers -Sessions $Sessions

                    Clear-TestConfiguration -Session $Sessions[0] -SystemConfig $SystemConfig
                    Clear-TestConfiguration -Session $Sessions[1] -SystemConfig $SystemConfig
                } finally {
                    Merge-Logs -DontCleanUp -LogSources $FileLogSources
                }
            }
        }

        BeforeAll {
            Initialize-PesterLogger -OutDir $LogDir

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "MultiNode",
                Justification="It's actually used."
            )]
            $MultiNode = New-MultiNodeSetup -TestenvConfFile $TestenvConfFile

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "FileLogSources",
                Justification="It's actually used in 'AfterEach' block."
            )]
            $FileLogSources = New-ComputeNodeLogSources -Sessions $MultiNode.Sessions
        }

        AfterAll {
            if (Get-Variable "MultiNode" -ErrorAction SilentlyContinue) {
                Remove-MultiNodeSetup -MultiNode $MultiNode
                Remove-Variable "MultiNode"
            }
        }
    }
}
