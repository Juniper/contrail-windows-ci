Param (
    [Parameter(Mandatory = $false)] [string] $TestenvConfFile,
    [Parameter(Mandatory = $false)] [string] $LogDir = 'pesterLogs',
    [Parameter(Mandatory = $false)] [bool] $PrepareEnv = $true,
    [Parameter(ValueFromRemainingArguments = $true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Init.ps1
. $PSScriptRoot\..\..\Utils\Testenv\Testbed.ps1

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

$ContrailProject = 'ci_tests_ip_fabric'
$DockerImages = @('microsoft/windowsservercore')
$ContainersIDs = @('jolly-lumberjack')
$ContainerNetInfos = @($null)

$Subnet = [Subnet]::new(
    '172.16.0.128',
    28,
    '172.16.0.129',
    '172.16.0.150',
    '172.16.0.180'
)

$ComputeAddressInUnderlay = '172.16.0.2'
$VirtualNetwork = [VirtualNetwork]::New('testnet_fabric_ip', $ContrailProject, $Subnet)

Test-WithRetries 3 {
    Describe 'IP Fabric tests' -Tag 'Smoke' {
        Context "Gateway-less forwarding" {
            It 'Container can ping compute node in underlay network' {
                Test-Ping `
                    -Session $Testenv.Sessions[0] `
                    -SrcContainerName $ContainersIDs[0] `
                    -DstContainerName "compute node in underlay network" `
                    -DstIP $ComputeAddressInUnderlay | Should Be 0
            }
        }

        BeforeAll {
            $Testenv = [Testenv]::New()
            $Testenv.Initialize($TestenvConfFile, $LogDir, $ContrailProject, $PrepareEnv)
            $BeforeAllStack = $Testenv.NewCleanupStack()

            Write-Log "Creating virtual network: $($VirtualNetwork.Name)"
            $ProviderNetworkFqName = [FqName]::new(@('default-domain', 'default-project', 'ip-fabric'))
            $ProviderNetworkUuid = $Testenv.ContrailRepo.FqNameToUuid('virtual-network', $ProviderNetworkFqName)
            $ProviderNetworkUrl = $Testenv.ContrailRepo.GetResourceUrl('virtual-network', $ProviderNetworkUuid)
            $VirtualNetwork.EnableIpFabricForwarding($ProviderNetworkFqName, $ProviderNetworkUuid, $ProviderNetworkUrl)
            $Testenv.ContrailRepo.AddOrReplace($VirtualNetwork) | Out-Null
            $BeforeAllStack.Push($VirtualNetwork)

            Write-Log 'Creating docker networks'
            foreach ($Session in $Testenv.Sessions) {
                Initialize-DockerNetworks `
                    -Session $Session `
                    -Networks @($VirtualNetwork) `
                    -TenantName $ContrailProject
                $BeforeAllStack.Push(${function:Remove-DockerNetwork}, @($Session, $VirtualNetwork.Name))
            }
        }

        AfterAll {
            $Testenv.Cleanup()
        }

        BeforeEach {
            $BeforeEachStack = $Testenv.NewCleanupStack()
            $BeforeEachStack.Push(${function:Merge-Logs}, @($Testenv.LogSources, $true))
            $BeforeEachStack.Push(${function:Remove-AllContainers}, @(, $Testenv.Sessions))
            Write-Log 'Creating containers'
            foreach ($i in $ContainersIDs.length) {
                Write-Log "Creating container: $($ContainersIDs[$i])"
                New-Container `
                    -Session $Testenv.Sessions[$i] `
                    -NetworkName $VirtualNetwork.Name `
                    -Name $ContainersIDs[$i] `
                    -Image $DockerImages[$i]

                $ContainerNetInfos[$i] = Get-RemoteContainerNetAdapterInformation `
                    -Session $Testenv.Sessions[$i] -ContainerID $ContainersIDs[$i]
                Write-Log "IP of $($ContainersIDs[$i]): $($ContainerNetInfos[$i].IPAddress)"
            }
            $ContainersLogs = @((New-ContainerLogSource -Sessions $Testenv.Sessions[0] -ContainerNames $ContainersIDs[0]),
                (New-ContainerLogSource -Sessions $Testenv.Sessions[1] -ContainerNames $ContainersIDs[1]))
            $BeforeEachStack.Push(${function:Merge-Logs}, @($ContainersLogs, $false))
        }

        AfterEach {
            $BeforeEachStack.RunCleanup($Testenv.ContrailRepo)
        }
    }
}
