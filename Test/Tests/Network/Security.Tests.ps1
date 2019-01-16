Param (
    [Parameter(Mandatory = $false)] [string] $TestenvConfFile = 'C:\source\xd\testenv-conf\testenv-conf.yaml',
    [Parameter(Mandatory = $false)] [string] $LogDir = 'pesterLogs',
    [Parameter(Mandatory = $false)] [bool] $PrepareEnv = $false,
    [Parameter(ValueFromRemainingArguments = $true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Init.ps1
. $PSScriptRoot\..\..\Utils\Testenv\Testbed.ps1

. $PSScriptRoot\..\..\Utils\ContrailAPI\ContrailAPI.ps1

. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

. $PSScriptRoot\..\..\TestConfigurationUtils.ps1

. $PSScriptRoot\..\..\Utils\WinContainers\Containers.ps1
. $PSScriptRoot\..\..\Utils\NetAdapterInfo\RemoteContainer.ps1
. $PSScriptRoot\..\..\Utils\Network\Connectivity.ps1
. $PSScriptRoot\..\..\Utils\DockerNetwork\Commands.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Initialize.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Configuration.ps1
. $PSScriptRoot\..\..\Utils\MultiNode\ContrailMultiNodeProvisioning.ps1
. $PSScriptRoot\..\..\Utils\DockerNetwork\Commands.ps1

$ContrailProject = 'ci_tests_security'

$NetworkPolicy = [NetworkPolicy]::new_PassAll('passallpolicy', $ContrailProject)

$ServerNetworkSubnet = [Subnet]::new(
    '10.2.2.0',
    24,
    '10.2.2.1',
    '10.2.2.11',
    '10.2.2.100'
)

$ClientNetworkSubnet = [Subnet]::new(
    '10.1.1.0',
    24,
    '10.1.1.1',
    '10.1.1.11',
    '10.1.1.100'
)

$GlobalTag = [Tag]::new('application', 'testapp')
$ServerNetworkTag = [Tag]::new('tier', 'server_testnet_security')
$ClientNetworkTag = [Tag]::new('tier', 'client_testnet_security')

$ServerNetwork = [VirtualNetwork]::New('server_testnet_security', $ContrailProject, $ServerNetworkSubnet)
$ServerNetwork.NetworkPolicysFqNames = @($NetworkPolicy.GetFqName())
$ServerNetwork.TagsFqNames = @($GlobalTag.GetFqName(), $ServerNetworkTag.GetFqName())
$ServerEndPoint = [TagsFirewallRuleEndpoint]::new(@($GlobalTag.GetName(), $ClientNetworkTag.GetName()))

$ClientNetwork = [VirtualNetwork]::New('client_testnet_security', $ContrailProject, $ClientNetworkSubnet)
$ClientNetwork.NetworkPolicysFqNames = @($NetworkPolicy.GetFqName())
$ClientNetwork.TagsFqNames = @($GlobalTag.GetFqName(), $ClientNetworkTag.GetFqName())
$ClientEndpoint = [TagsFirewallRuleEndpoint]::new(@($GlobalTag.GetName(), $ServerNetworkTag.GetName()))

$Networks = @($ServerNetwork, $ClientNetwork)

$Containers = @{
    'server' = @{
        'Name'         = 'jolly-lumberjack'
        'Image'        = 'python-http'
        'NetInfo'      = $null
        'HostSession'  = $null
        'Network'      = $ServerNetwork
    }
    'client' = @{
        'Name'         = 'juniper-tree'
        'Image'        = 'microsoft/windowsservercore'
        'NetInfo'      = $null
        'HostSession'  = $null
        'Network'      = $ClientNetwork
    }
}

function Initialize-Security {
    Param (
        [Parameter(Mandatory = $true)] [CleanUpStack] $CleanupStack,
        [Parameter(Mandatory = $true)] [FirewallRule[]] $FirewallRules,
        [Parameter(Mandatory = $true)] [ContrailRepo] $ContrailRepo
    )

    $FirewallPolicy = [FirewallPolicy]::new('test-firewall-policy')

    foreach ($FirewallRule in $FirewallRules) {
        Write-Log "Creating firewall rule: $($FirewallRule.Name)"
        $ContrailRepo.AddOrReplace($FirewallRule) | Out-Null
        $FirewallPolicy.AddFirewallRule($FirewallRule.GetFqName(), 0)
        $CleanupStack.Push($FirewallRule)
    }

    Write-Log "Creating firewall policy: $($FirewallPolicy.Name)"
    $ContrailRepo.AddOrReplace($FirewallPolicy) | Out-Null
    $CleanupStack.Push($FirewallPolicy)

    $ApplicationPolicy = [ApplicationPolicy]::new('test-app-policy', @($FirewallPolicy.GetFqName()), @($GlobalTag.GetFqName()))
    Write-Log "Creating application policy: $($ApplicationPolicy.Name)"
    $ContrailRepo.AddOrReplace($ApplicationPolicy) | Out-Null
    $CleanupStack.Push($ApplicationPolicy)
}

function Test-Security {
    Param (
        [Parameter(Mandatory = $true)] [FirewallRule[]] $TestRules,
        [Parameter(Mandatory = $true)] [ContrailRepo] $ContrailRepo,
        [Parameter(Mandatory = $true)] [ScriptBlock] $TestInvocation
    )

    $TestCleanupStack = $Testenv.NewCleanupStack()

    Initialize-Security `
        -CleanupStack $TestCleanupStack `
        -FirewallRules $TestRules `
        -ContrailRepo $ContrailRepo | Out-Null

    Invoke-Command $TestInvocation

    $TestCleanupStack.RunCleanup($ContrailRepo)
}

Test-WithRetries 1 {
    Describe 'Contrail-Security tests' -Tag 'Smoke' {
        Context 'TCP' {
            It 'Passes all the traffic' {
                $TestRules = @(
                    [FirewallRule]::new(
                        'test-firewall-rule-tcp-pass-biway-full',
                        [BiFirewallDirection]::new(),
                        [SimplePassRuleAction]::new(),
                        [FirewallService]::new_TCP_Full(),
                        $ServerEndPoint,
                        $ClientEndpoint
                    )
                )

                Test-Security -TestRules $TestRules -ContrailRepo $Testenv.ContrailRepo {
                    Test-TCP `
                        -Session $Containers.client.HostSession `
                        -SrcContainerName $Containers.client.Name `
                        -DstContainerName $Containers.server.Name `
                        -DstIP $Containers.server.NetInfo.IPAddress | Should Be 0
                }
            }

            It 'Denies all the traffic' {
                $TestRules = @(
                    [FirewallRule]::new(
                        'test-firewall-rule-tcp-deny-biway-full',
                        [BiFirewallDirection]::new(),
                        [SimpleDenyRuleAction]::new(),
                        [FirewallService]::new_TCP_Full(),
                        $ServerEndPoint,
                        $ClientEndpoint
                    )
                )

                Test-Security -TestRules $TestRules -ContrailRepo $Testenv.ContrailRepo {
                    { Test-TCP `
                        -Session $Containers.client.HostSession `
                        -SrcContainerName $Containers.client.Name `
                        -DstContainerName $Containers.server.Name `
                        -DstIP $Containers.server.NetInfo.IPAddress } | Should -Throw "Invoke-WebRequest"
                }
            }
        }

        Context 'UDP' {
            # It 'Passes only one way traffic on all ports' {
            #     $TestRules = @(
            #         [FirewallRule]::new(
            #             'test-firewall-rule-udp-pass-uniway-full',
            #             [UniLeftFirewallDirection]::new(),
            #             [SimplePassRuleAction]::new(),
            #             [FirewallService]::new_UDP_Full(),
            #             $ServerEndPoint,
            #             $ClientEndpoint
            #         ),
            #         [FirewallRule]::new(
            #             'test-firewall-rule-udp-deny-biway-full',
            #             [BiFirewallDirection]::new(),
            #             [SimpleDenyRuleAction]::new(),
            #             [FirewallService]::new_UDP_Full(),
            #             $ServerEndPoint,
            #             $ClientEndpoint
            #         )
            #     )

            #     Test-Security -TestRules $TestRules -ContrailRepo $Testenv.ContrailRepo {
            #         Test-UDP `
            #             -ListenerContainerSession $Containers.server.HostSession `
            #             -ListenerContainerName $Containers.server.Name `
            #             -ListenerContainerIP $Containers.server.NetInfo.IPAddress `
            #             -ClientContainerSession $Containers.client.HostSession `
            #             -ClientContainerName $Containers.client.Name `
            #             -Message 'With contrail-security i feel safe now.' | Should Be $true

            #         Test-UDP `
            #             -ListenerContainerSession $Containers.client.HostSession `
            #             -ListenerContainerName $Containers.client.Name `
            #             -ListenerContainerIP $Containers.client.NetInfo.IPAddress `
            #             -ClientContainerSession $Containers.server.HostSession `
            #             -ClientContainerName $Containers.server.Name `
            #             -Message 'With contrail-security i feel safe now.' | Should Be $false
            #     }
            # }

            It 'Denies traffic on src port' {
                $TestRules = @(
                    [FirewallRule]::new(
                        'test-firewall-rule-udp-pass-uniway-range',
                        [BiFirewallDirection]::new(),
                        [SimplePassRuleAction]::new(),
                        [FirewallService]::new_udp_range(1111, 2222),
                        $ServerEndPoint,
                        $ClientEndpoint
                    ),
                    [FirewallRule]::new(
                        'test-firewall-rule-udp-deny-biway-full',
                        [BiFirewallDirection]::new(),
                        [SimplePassRuleAction]::new(),
                        [FirewallService]::new_UDP_Full(),
                        $ServerEndPoint,
                        $ClientEndpoint
                    )
                )

                Test-Security -TestRules $TestRules -ContrailRepo $Testenv.ContrailRepo {
                    Test-UDP `
                        -ListenerContainerSession $Containers.server.HostSession `
                        -ListenerContainerName $Containers.server.Name `
                        -ListenerContainerIP $Containers.server.NetInfo.IPAddress `
                        -ClientContainerSession $Containers.client.HostSession `
                        -ClientContainerName $Containers.client.Name `
                        -Message 'With contrail-security i feel safe now.' `
                        -UDPServerPort 1111 `
                        -UDPClientPort 2222 | Should Be $true

                    Test-UDP `
                        -ListenerContainerSession $Containers.server.HostSession `
                        -ListenerContainerName $Containers.server.Name `
                        -ListenerContainerIP $Containers.server.NetInfo.IPAddress `
                        -ClientContainerSession $Containers.client.HostSession `
                        -ClientContainerName $Containers.client.Name `
                        -Message 'With contrail-security i feel safe now.' `
                        -UDPServerPort 3333 `
                        -UDPClientPort 4444 | Should Be $false
                }
            }
        }

        BeforeAll {
            $Testenv = [Testenv]::New()
            $Testenv.Initialize($TestenvConfFile, $LogDir, $ContrailProject, $PrepareEnv)

            $Containers.client.HostSession = $Testenv.Sessions[0]
            $Containers.server.HostSession = $Testenv.Sessions[1]

            $BeforeAllStack = $Testenv.NewCleanupStack()

            Write-Log "Adding global application tag: $($GlobalTag.GetName())"
            $Testenv.ContrailRepo.AddOrReplace($GlobalTag) | Out-Null
            $BeforeAllStack.Push($GlobalTag)

            Write-Log "Creating network policy: $($NetworkPolicy.Name)"
            $Testenv.ContrailRepo.AddOrReplace($NetworkPolicy) | Out-Null
            $BeforeAllStack.Push($NetworkPolicy)

            Write-Log "Adding tag $($ClientNetworkTag.GetName()) for $($ClientNetwork.Name)"
            $Testenv.ContrailRepo.AddOrReplace($ClientNetworkTag)
            $BeforeAllStack.Push($ClientNetworkTag)

            Write-Log "Creating virtual network: $($ClientNetwork.Name)"
            $Testenv.ContrailRepo.AddOrReplace($ClientNetwork) | Out-Null
            $BeforeAllStack.Push($ClientNetwork)

            Write-Log "Adding tag $($ServerNetworkTag.GetName()) for $($ServerNetwork.Name)"
            $Testenv.ContrailRepo.AddOrReplace($ServerNetworkTag)
            $BeforeAllStack.Push($ServerNetworkTag)

            Write-Log "Creating virtual network: $($ServerNetwork.Name)"
            $Testenv.ContrailRepo.AddOrReplace($ServerNetwork) | Out-Null
            $BeforeAllStack.Push($ServerNetwork)

            Write-Log 'Creating docker networks'
            foreach ($Session in $Testenv.Sessions) {
                Initialize-DockerNetworks `
                    -Session $Session `
                    -Networks $Networks  `
                    -TenantName $ContrailProject
                $BeforeAllStack.Push(${function:Remove-DockerNetwork}, @($Session, $ClientNetwork.Name))
                $BeforeAllStack.Push(${function:Remove-DockerNetwork}, @($Session, $ServerNetwork.Name))
            }
        }

        AfterAll {
            $Testenv.Cleanup()
        }

        BeforeEach {
            $BeforeEachStack = $Testenv.NewCleanupStack()
            $BeforeEachStack.Push(${function:Merge-Logs}, @($Testenv.LogSources, $true))
            $BeforeEachStack.Push(${function:Remove-AllContainers}, @(, $Testenv.Sessions))
            $ContainersLogs = @()
            Write-Log 'Creating containers'
            foreach ($Key in $Containers.Keys) {
                $Container = $Containers[$Key]
                Write-Log "Creating container: $($Container.Name)"
                New-Container `
                    -Session $Container.HostSession `
                    -NetworkName $Container.Network.Name `
                    -Name $Container.Name `
                    -Image $Container.Image

                $Container.NetInfo = Get-RemoteContainerNetAdapterInformation `
                    -Session $Container.HostSession -ContainerID $Container.Name
                $ContainersLogs += New-ContainerLogSource -Sessions $Container.HostSession -ContainerNames $Container.Name
                Write-Log "IP of $($Container.Name): $($Container.NetInfo.IPAddress)"
            }
            $BeforeEachStack.Push(${function:Merge-Logs}, @($ContainersLogs, $false))
        }

        AfterEach {
            $BeforeEachStack.RunCleanup($Testenv.ContrailRepo)
        }
    }
}
