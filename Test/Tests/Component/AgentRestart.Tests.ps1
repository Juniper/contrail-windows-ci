Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs",
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Init.ps1

. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1

. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\Utils\NetAdapterInfo\RemoteContainer.ps1
. $PSScriptRoot\..\..\Utils\Network\Connectivity.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Initialize.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Service.ps1
. $PSScriptRoot\..\..\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\..\Utils\MultiNode\ContrailMultiNodeProvisioning.ps1

$Container1ID = "jolly-lumberjack"
$Container2ID = "juniper-tree"
$Container3ID = "mountain-mama"

$Subnet = [SubnetConfiguration]::new(
    "10.0.5.0",
    24,
    "10.0.5.1",
    "10.0.5.19",
    "10.0.5.83"
)
$Network = [Network]::New("testnet14", $Subnet)

function Restart-Agent {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $ServiceName = Get-AgentServiceName
    Invoke-Command -Session $Session -ScriptBlock {
        Restart-Service $Using:ServiceName
    } | Out-Null
}

function Get-NumberOfStoredPorts {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $NumberOfStoredPorts = Invoke-Command -Session $Session -ScriptBlock {
        $PortsDir = "C:\\ProgramData\\Contrail\\var\\lib\\contrail\\ports"
        if (-not (Test-Path $PortsDir)) {
            return 0
        }
        return @(Get-ChildItem -Path $PortsDir -File).Length
    }
    return $NumberOfStoredPorts
}

Test-WithRetries 3 {
    # "Unpendify" once "Replay add port" is merged.
    Describe "Agent restart tests" {
        It "Ports are correctly restored after Agent restart" -Pending {
            Write-Log "Testing ping before Agent restart..."
            Test-Ping `
                -Session $Sessions[0] `
                -SrcContainerName $Container1ID `
                -DstContainerName $Container2ID `
                -DstIP $Container2NetInfo.IPAddress | Should Be 0

            Get-NumberOfStoredPorts -Session $Sessions[0] | Should Be 1
            Restart-Agent -Session $Sessions[0]

            Write-Log "Testing ping after Agent restart..."
            Test-Ping `
                -Session $Sessions[0] `
                -SrcContainerName $Container1ID `
                -DstContainerName $Container2ID `
                -DstIP $Container2NetInfo.IPAddress | Should Be 0

            Write-Log "Creating container: $Container3ID"
            New-Container `
                -Session $MultiNode.Sessions[1] `
                -NetworkName $Network.Name `
                -Name $Container3ID `
                -Image "microsoft/windowsservercore"

            $Container3NetInfo = Get-RemoteContainerNetAdapterInformation `
                -Session $MultiNode.Sessions[1] -ContainerID $Container3ID
            $IP = $Container3NetInfo.IPAddress
            Write-Log "IP of ${Container3ID}: $IP"

            Get-NumberOfStoredPorts -Session $Sessions[0] | Should Be 1

            Write-Log "Testing ping after Agent restart with new container..."
            Test-Ping `
                -Session $Sessions[0] `
                -SrcContainerName $Container1ID `
                -DstContainerName $Container3ID `
                -DstIP $Container3NetInfo.IPAddress | Should Be 0

            Remove-Container -Session $Sessions[0] -NameOrId $Container1ID
            Get-NumberOfStoredPorts -Session $Sessions[0] | Should Be 0
        }

        BeforeAll {
            Initialize-PesterLogger -OutDir $LogDir
            $MultiNode = New-MultiNodeSetup -TestenvConfFile $TestenvConfFile
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "Sessions",
                Justification="It's actually used."
            )]
            $Sessions = $MultiNode.Sessions

            Write-Log "Creating virtual network: $($Network.Name)"
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "ContrailNetwork",
                Justification="It's actually used."
            )]
            $ContrailNetwork = $MultiNode.NM.AddOrReplaceNetwork($null, $Network.Name, $Subnet)

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "FileLogSources",
                Justification="It's actually used."
            )]
            $FileLogSources = New-ComputeNodeLogSources -Sessions $MultiNode.Sessions

            Initialize-ComputeNode -Session $MultiNode.Sessions[0] -Networks @($Network) -Configs $MultiNode.Configs
            Initialize-ComputeNode -Session $MultiNode.Sessions[1] -Networks @($Network) -Configs $MultiNode.Configs
        }

        AfterAll {
            if (Get-Variable "MultiNode" -ErrorAction SilentlyContinue) {
                $Sessions = $MultiNode.Sessions
                $SystemConfig = $MultiNode.Configs.System

                Clear-TestConfiguration -Session $Sessions[0] -SystemConfig $SystemConfig
                Clear-TestConfiguration -Session $Sessions[1] -SystemConfig $SystemConfig
                Clear-Logs -LogSources $FileLogSources

                Write-Log "Deleting virtual network"
                if (Get-Variable ContrailNetwork -ErrorAction SilentlyContinue) {
                    $MultiNode.NM.RemoveNetwork($ContrailNetwork)
                }

                Remove-MultiNodeSetup -MultiNode $MultiNode
                Remove-Variable "MultiNode"
            }
        }

        BeforeEach {
            Write-Log "Creating containers"
            Write-Log "Creating container: $Container1ID"
            New-Container `
                -Session $MultiNode.Sessions[0] `
                -NetworkName $Network.Name `
                -Name $Container1ID `
                -Image "microsoft/windowsservercore"
            Write-Log "Creating container: $Container2ID"
            New-Container `
                -Session $MultiNode.Sessions[1] `
                -NetworkName $Network.Name `
                -Name $Container2ID `
                -Image "microsoft/windowsservercore"

            Write-Log "Getting containers' NetAdapter Information"
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "Container1NetInfo",
                Justification="It's actually used."
            )]
            $Container1NetInfo = Get-RemoteContainerNetAdapterInformation `
                -Session $MultiNode.Sessions[0] -ContainerID $Container1ID
            $IP = $Container1NetInfo.IPAddress
            Write-Log "IP of ${Container1ID}: $IP"
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "Container2NetInfo",
                Justification="It's actually used."
            )]
            $Container2NetInfo = Get-RemoteContainerNetAdapterInformation `
                -Session $MultiNode.Sessions[1] -ContainerID $Container2ID
            $IP = $Container2NetInfo.IPAddress
            Write-Log "IP of ${Container2ID}: $IP"
        }

        AfterEach {
            $Sessions = $MultiNode.Sessions

            try {
                Merge-Logs -LogSources (
                    (New-ContainerLogSource -Sessions $Sessions[0] -ContainerNames $Container1ID),
                    (New-ContainerLogSource -Sessions $Sessions[1] -ContainerNames $Container2ID)
                )

                Write-Log "Removing all containers"
                Remove-AllContainers -Sessions $Sessions
                Start-AgentService -Session $Sessions[0]
            } finally {
                Merge-Logs -DontCleanUp -LogSources $FileLogSources
            }
        }
    }
}
