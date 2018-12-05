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
. $PSScriptRoot\..\..\Utils\ContrailAPI_New\VirtualNetwork.ps1
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
                $NetworkPolicyRepo.AddOrReplace($NetworkPolicy) | Out-Null

                Write-Log "Creating virtual network: $($ClientNetwork.Name)"
                $ClientSubnet = [Subnet]::new(
                    $ClientNetworkSubnet.IpPrefix,
                    $ClientNetworkSubnet.IpPrefixLen,
                    $ClientNetworkSubnet.DefaultGateway,
                    $ClientNetworkSubnet.AllocationPoolsStart,
                    $ClientNetworkSubnet.AllocationPoolsEnd)
                $ClientVirtualNetwork = [VirtualNetwork]::new($ClientNetwork.Name, $MultiNode.NM.DefaultTenantName, $ClientSubnet)
                $Response = $VirtualNetworkRepo.AddOrReplace($ClientVirtualNetwork)
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailClientNetwork",
                    Justification = "It's actually used."
                )]
                $ContrailClientNetwork = $Response.'virtual-network'.'uuid'

                Write-Log "Creating virtual network: $($ServerNetwork.Name)"
                $ServerSubnet = [Subnet]::new(
                    $ServerNetworkSubnet.IpPrefix,
                    $ServerNetworkSubnet.IpPrefixLen,
                    $ServerNetworkSubnet.DefaultGateway,
                    $ServerNetworkSubnet.AllocationPoolsStart,
                    $ServerNetworkSubnet.AllocationPoolsEnd)
                $ServerVirtualNetwork = [VirtualNetwork]::new($ServerNetwork.Name, $MultiNode.NM.DefaultTenantName, $ServerSubnet)
                $Response = $VirtualNetworkRepo.AddOrReplace($ServerVirtualNetwork)
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailServerNetwork",
                    Justification = "It's actually used."
                )]
                $ContrailServerNetwork = $Response.'virtual-network'.'uuid'

                Write-Log "Creating floating IP pool: $ServerFloatingIpPoolName"
                $FloatingIpPool = [FloatingIpPool]::new($ServerFloatingIpPoolName, $ServerNetwork.Name, $MultiNode.NM.DefaultTenantName)
                $Response = $FloatingIpPoolRepo.AddOrReplace($FloatingIpPool)
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailFloatingIpPool",
                    Justification = "It's actually used."
                )]
                $ContrailFloatingIpPool = $Response.'floating-ip-pool'.'uuid'

                $ClientVirtualNetwork.NetworkPolicys = @($NetworkPolicy)
                $ServerVirtualNetwork.NetworkPolicys = @($NetworkPolicy)
                $VirtualNetworkRepo.Set($ClientVirtualNetwork)
                $VirtualNetworkRepo.Set($ServerVirtualNetwork)

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
                    $VirtualNetworkRepo.RemoveWithDependencies($ServerVirtualNetwork) | Out-Null
                }

                Write-Log "Deleting virtual network"
                if (Get-Variable ContrailClientNetwork -ErrorAction SilentlyContinue) {
                    $VirtualNetworkRepo.RemoveWithDependencies($ClientVirtualNetwork) | Out-Null
                }

                Write-Log "Deleting network policy"
                $NetworkPolicy = [NetworkPolicy]::new($PolicyName, $MultiNode.NM.DefaultTenantName)
                $NetworkPolicyRepo.Remove($NetworkPolicy) | Out-Null
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

                $PortFqNames = $VirtualNetworkRepo.GetPorts($ServerVirtualNetwork)

                $ContrailFloatingIp.PortFqNames = $PortFqNames

                $FloatingIpRepo.Set($ContrailFloatingIp)
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
            $NetworkPolicyRepo = [ContrailRepo]::new($MultiNode.NM)
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "FloatingIpPoolRepo",
                Justification = "It's actually used."
            )]
            $FloatingIpPoolRepo = [ContrailRepo]::new($MultiNode.NM)
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "FloatingIpRepo",
                Justification = "It's actually used."
            )]
            $FloatingIpRepo = [ContrailRepo]::new($MultiNode.NM)
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "VirtualNetworkRepo",
                Justification = "It's actually used."
            )]
            $VirtualNetworkRepo = [VirtualNetworkRepo]::new($MultiNode.NM)

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
