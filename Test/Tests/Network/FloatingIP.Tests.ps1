Param (
    [Parameter(Mandatory = $false)] [string] $TestenvConfFile,
    [Parameter(Mandatory = $false)] [string] $LogDir = "pesterLogs",
    [Parameter(Mandatory = $false)] [bool] $PrepareEnv = $true,
    [Parameter(ValueFromRemainingArguments = $true)] $UnusedParams
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

. $PSScriptRoot\..\..\Utils\ContrailAPI_New\NetworkPolicy.ps1
. $PSScriptRoot\..\..\Utils\ContrailAPI_New\FloatingIPPool.ps1
. $PSScriptRoot\..\..\Utils\ContrailAPI\VirtualNetwork.ps1
. $PSScriptRoot\..\..\Utils\ContrailAPI_New\FloatingIP.ps1

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

$Networks = @($ClientNetwork, $ServerNetwork)

$ContainerImage = "microsoft/windowsservercore"
$ContainerClientID = "fip-client"
$ContainerServer1ID = "fip-server1"

Describe "Floating IP" -Tag "Smoke" {
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
                $NetworkPolicy = [NetworkPolicy]::new_PassAll($PolicyName, $MultiNode.NM.DefaultTenantName)
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailPolicy",
                    Justification = "It's actually used."
                )]
                $Response = $NetworkPolicyRepo.AddOrReplace($NetworkPolicy)
                $ContrailPolicy = $Response.'network-policy'.'uuid'

                Write-Log "Creating virtual network: $ClientNetwork.Name"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailClientNetwork",
                    Justification = "It's actually used."
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
                    Justification = "It's actually used."
                )]
                $ContrailServerNetwork = Add-OrReplaceNetwork `
                    -API $MultiNode.NM `
                    -TenantName $MultiNode.NM.DefaultTenantName `
                    -Name $ServerNetwork.Name `
                    -SubnetConfig $ServerNetwork.Subnet

                Write-Log "Creating floating IP pool: $ServerFloatingIpPoolName"
                $FloatingIpPool = [FloatingIpPool]::new($ServerFloatingIpPoolName, $ServerNetwork.Name, $MultiNode.NM.DefaultTenantName)
                $Response = $FloatingIpPoolRepo.AddOrReplace($FloatingIpPool)
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailFloatingIpPool",
                    Justification = "It's actually used."
                )]
                $ContrailFloatingIpPool = $Response.'floating-ip-pool'.'uuid'

                Add-ContrailPolicyToNetwork `
                    -API $MultiNode.NM `
                    -PolicyUuid $ContrailPolicy `
                    -NetworkUuid $ContrailClientNetwork

                Add-ContrailPolicyToNetwork `
                    -API $MultiNode.NM `
                    -PolicyUuid $ContrailPolicy `
                    -NetworkUuid $ContrailServerNetwork

                foreach ($Session in $MultiNode.Sessions) {
                    Initialize-DockerNetworks `
                        -Session $Session `
                        -Networks $Networks `
                        -Configs $MultiNode.Configs
                }
            }

            AfterAll {
                foreach ($Session in $MultiNode.Sessions) {
                    foreach ($Network in $Networks) {
                        Remove-DockerNetwork -Session $Session -Name $Network.Name
                    }
                }

                Write-Log "Deleting floating IP pool"
                if (Get-Variable ContrailFloatingIpPool -ErrorAction SilentlyContinue) {
                    $FloatingIpPool = [FloatingIpPool]::new($ServerFloatingIpPoolName, $ServerNetwork.Name, $MultiNode.NM.DefaultTenantName)
                    $FloatingIpPoolRepo.Remove($FloatingIpPool) | Out-Null
                }

                Write-Log "Deleting virtual network"
                if (Get-Variable ContrailServerNetwork -ErrorAction SilentlyContinue) {
                    Remove-ContrailVirtualNetwork `
                        -API $MultiNode.NM `
                        -Uuid $ContrailServerNetwork
                }

                Write-Log "Deleting virtual network"
                if (Get-Variable ContrailClientNetwork -ErrorAction SilentlyContinue) {
                    Remove-ContrailVirtualNetwork `
                        -API $MultiNode.NM `
                        -Uuid $ContrailClientNetwork
                }

                Write-Log "Deleting network policy"
                if (Get-Variable ContrailPolicy -ErrorAction SilentlyContinue) {
                    $NetworkPolicy = [NetworkPolicy]::new($PolicyName, $MultiNode.NM.DefaultTenantName)
                    $NetworkPolicyRepo.Remove($NetworkPolicy) | Out-Null
                }
            }

            BeforeEach {
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
                $ContrailFloatingIp = [FloatingIp]::new($ServerFloatingIpName, $FloatingIpPool.GetFQName(), $ServerFloatingIpAddress)
                $FloatingIpRepo.AddOrReplace($ContrailFloatingIp) | Out-Null

                $PortFqNames = Get-ContrailVirtualNetworkPorts `
                    -API $MultiNode.NM `
                    -NetworkUuid $ContrailServerNetwork

                $ContrailFloatingIp.PortFqNames = $PortFqNames

                $FloatingIpRepo.SetPorts($ContrailFloatingIp)
            }

            AfterEach {
                Write-Log "Deleting floating IP"
                if (Get-Variable ContrailFloatingIp -ErrorAction SilentlyContinue) {
                    $FloatingIpRepo.Remove($ContrailFloatingIp)
                }

                $Sessions = $MultiNode.Sessions
                try {
                    Merge-Logs -LogSources (
                        (New-ContainerLogSource -Sessions $Sessions[0] -ContainerNames $ContainerClientID),
                        (New-ContainerLogSource -Sessions $Sessions[1] -ContainerNames $ContainerServer1ID)
                    )

                    Write-Log "Removing all containers"
                    Remove-AllContainers -Sessions $Sessions
                }
                finally {
                    Merge-Logs -DontCleanUp -LogSources $FileLogSources
                }
            }
        }

        BeforeAll {
            Initialize-PesterLogger -OutDir $LogDir

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "MultiNode",
                Justification = "It's actually used."
            )]
            $MultiNode = New-MultiNodeSetup -TestenvConfFile $TestenvConfFile
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "NetworkPolicyRepo",
                Justification = "It's actually used."
            )]
            $NetworkPolicyRepo = [NetworkPolicyRepo]::new($MultiNode.NM)
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "FloatingIpPoolRepo",
                Justification = "It's actually used."
            )]
            $FloatingIpPoolRepo = [FloatingIpPoolRepo]::new($MultiNode.NM)
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "FloatingIpRepo",
                Justification = "It's actually used."
            )]
            $FloatingIpRepo = [FloatingIpRepo]::new($MultiNode.NM)

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "FileLogSources",
                Justification = "It's actually used in 'AfterEach' block."
            )]
            $FileLogSources = New-ComputeNodeLogSources -Sessions $MultiNode.Sessions

            if ($PrepareEnv) {
                foreach ($Session in $MultiNode.Sessions) {
                    Initialize-ComputeNode -Session $Session -Configs $MultiNode.Configs
                }
            }
        }

        AfterAll {
            if (Get-Variable "MultiNode" -ErrorAction SilentlyContinue) {
                if ($PrepareEnv) {
                    foreach ($Session in $MultiNode.Sessions) {
                        Clear-ComputeNode `
                            -Session $Session `
                            -SystemConfig $MultiNode.Configs.System
                    }
                    Clear-Logs -LogSources $FileLogSources
                }
                Remove-MultiNodeSetup -MultiNode $MultiNode
                Remove-Variable "MultiNode"
            }
        }
    }
}
