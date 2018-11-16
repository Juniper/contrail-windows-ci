Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs",
    [Parameter(Mandatory=$false)] [bool] $PrepareEnv = $true,
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1

. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\Utils\Network\Connectivity.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Initialize.ps1
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
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailPolicy",
                    Justification="It's actually used."
                )]
                $ContrailPolicy = $MultiNode.NM.AddPassAllPolicyOnDefaultTenant($PolicyName)

                Write-Log "Creating virtual network: $ClientNetwork.Name"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailClientNetwork",
                    Justification="It's actually used."
                )]
                $ContrailClientNetwork = $MultiNode.NM.AddOrReplaceNetwork($null, $ClientNetwork.Name, $ClientNetwork.Subnet)

                Write-Log "Creating virtual network: $ServerNetwork.Name"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailServerNetwork",
                    Justification="It's actually used."
                )]
                $ContrailServerNetwork = $MultiNode.NM.AddOrReplaceNetwork($null, $ServerNetwork.Name, $ServerNetwork.Subnet)

                Write-Log "Creating floating IP pool: $ServerFloatingIpPoolName"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailFloatingIpPool",
                    Justification="It's actually used."
                )]
                $ContrailFloatingIpPool = $MultiNode.NM.AddFloatingIpPool($null, $ServerNetwork.Name, $ServerFloatingIpPoolName)

                $MultiNode.NM.AddPolicyToNetwork($ContrailPolicy, $ContrailClientNetwork)
                $MultiNode.NM.AddPolicyToNetwork($ContrailPolicy, $ContrailServerNetwork)

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
                    $MultiNode.NM.RemoveFloatingIpPool($ContrailFloatingIpPool)
                }

                Write-Log "Deleting virtual network"
                if (Get-Variable ContrailServerNetwork -ErrorAction SilentlyContinue) {
                    $MultiNode.NM.RemoveNetwork($ContrailServerNetwork)
                }

                Write-Log "Deleting virtual network"
                if (Get-Variable ContrailClientNetwork -ErrorAction SilentlyContinue) {
                    $MultiNode.NM.RemoveNetwork($ContrailClientNetwork)
                }

                Write-Log "Deleting network policy"
                if (Get-Variable ContrailPolicy -ErrorAction SilentlyContinue) {
                    $MultiNode.NM.RemovePolicy($ContrailPolicy)
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
                $ContrailFloatingIp = $MultiNode.NM.AddFloatingIp($ContrailFloatingIpPool,
                                                                  $ServerFloatingIpName,
                                                                  $ServerFloatingIpAddress)

                $MultiNode.NM.AssignFloatingIpToAllPortsInNetwork($ContrailFloatingIp, $ContrailServerNetwork)
            }

            AfterEach {
                Write-Log "Deleting floating IP"
                if (Get-Variable ContrailFloatingIp -ErrorAction SilentlyContinue) {
                    $MultiNode.NM.RemoveFloatingIp($ContrailFloatingIp)
                }

                $Sessions = $MultiNode.Sessions
                try {
                    Merge-Logs -LogSources (
                        (New-ContainerLogSource -Sessions $Sessions[0] -ContainerNames $ContainerClientID),
                        (New-ContainerLogSource -Sessions $Sessions[1] -ContainerNames $ContainerServer1ID)
                    )

                    Write-Log "Removing all containers"
                    Remove-AllContainers -Sessions $Sessions
                } finally {
                    Merge-Logs -DontCleanUp -LogSources (New-FileLogSource -Path (Get-ComputeLogsPath) -Sessions $Sessions)
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

            if ($PrepareEnv) {
                foreach ($Session in $MultiNode.Sessions) {
                    Initialize-ComputeNode -Session $Session -Configs $MultiNode.Configs
                }
            }
        }

        AfterAll {
            if (Get-Variable "MultiNode" -ErrorAction SilentlyContinue) {
                if ($PrepareEnv){
                    foreach ($Session in $MultiNode.Sessions) {
                        Clear-ComputeNode `
                            -Session $Session `
                            -SystemConfig $MultiNode.Configs.System
                    }
                }
                Remove-MultiNodeSetup -MultiNode $MultiNode
                Remove-Variable "MultiNode"
            }
        }
    }
}
