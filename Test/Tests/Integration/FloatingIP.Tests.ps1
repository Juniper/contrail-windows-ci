Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs",
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1
. $PSScriptRoot\..\..\Utils\ComponentsInstallation.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Initialize.ps1
. $PSScriptRoot\..\..\Utils\ContrailNetworkManager.ps1

function Test-Ping {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $SrcContainerName,
        [Parameter(Mandatory=$true)] [String] $DstIP,
        [Parameter(Mandatory=$false)] [Int] $BufferSize = 32
    )

    Write-Log "Container $SrcContainerName is pinging $DstIP..."
    $Res = Invoke-Command -Session $Session -ScriptBlock {
        docker exec $Using:SrcContainerName powershell `
            "ping -l $Using:BufferSize $Using:DstIP; `$LASTEXITCODE;"
    }
    $Output = $Res[0..($Res.length - 2)]
    Write-Log "Ping output: $Output"
    return $Res[-1]
}

$PolicyName = "passallpolicy"

$ClientNetworkName = "network1"
$ClientNetworkSubnet = [SubnetConfiguration]::new(
    "10.1.1.0",
    24,
    "10.1.1.1",
    "10.1.1.11",
    "10.1.1.100"
)

$ServerNetworkName = "network2"
$ServerNetworkSubnet = [SubnetConfiguration]::new(
    "10.2.2.0",
    24,
    "10.2.2.1",
    "10.2.2.11",
    "10.2.2.100"
)

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
                    -Session $Sessions[0] `
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
                $ContrailPolicy = $ContrailNM.AddPassAllPolicyOnDefaultTenant($PolicyName)

                Write-Log "Creating virtual network: $ClientNetworkName"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailClientNetwork",
                    Justification="It's actually used."
                )]
                $ContrailClientNetwork = $ContrailNM.AddNetwork($null, $ClientNetworkName, $ClientNetworkSubnet)

                Write-Log "Creating virtual network: $ServerNetworkName"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailServerNetwork",
                    Justification="It's actually used."
                )]
                $ContrailServerNetwork = $ContrailNM.AddNetwork($null, $ServerNetworkName, $ServerNetworkSubnet)

                Write-Log "Creating floating IP pool: $ServerFloatingIpPoolName"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailFloatingIpPool",
                    Justification="It's actually used."
                )]
                $ContrailFloatingIpPool = $ContrailNM.AddFloatingIpPool($null, $ServerNetworkName, $ServerFloatingIpPoolName)

                $ContrailNM.AddPolicyToNetwork($ContrailPolicy, $ContrailClientNetwork)
                $ContrailNM.AddPolicyToNetwork($ContrailPolicy, $ContrailServerNetwork)
            }

            AfterAll {
                Write-Log "Deleting floating IP pool"
                if (Get-Variable ContrailFloatingIpPool -ErrorAction SilentlyContinue) {
                    $ContrailNM.RemoveFloatingIpPool($ContrailFloatingIpPool)
                }

                Write-Log "Deleting virtual network"
                if (Get-Variable ContrailServerNetwork -ErrorAction SilentlyContinue) {
                    $ContrailNM.RemoveNetwork($ContrailServerNetwork)
                }

                Write-Log "Deleting virtual network"
                if (Get-Variable ContrailClientNetwork -ErrorAction SilentlyContinue) {
                    $ContrailNM.RemoveNetwork($ContrailClientNetwork)
                }

                Write-Log "Deleting network policy"
                if (Get-Variable ContrailPolicy -ErrorAction SilentlyContinue) {
                    $ContrailNM.RemovePolicy($ContrailPolicy)
                }
            }

            BeforeEach {
                $Networks = @($ClientNetworkName, $ServerNetworkName)
                foreach ($Session in $Sessions) {
                    Initialize-ComputeNode -Session $Session -Networks $Networks
                }

                Write-Log "Creating containers"
                Write-Log "Creating container: $ContainerClientID"
                New-Container `
                    -Session $Sessions[0] `
                    -NetworkName $ClientNetworkName `
                    -Name $ContainerClientID `
                    -Image $ContainerImage

                Write-Log "Creating containers"
                Write-Log "Creating container: $ContainerServer1ID"
                New-Container `
                    -Session $Sessions[1] `
                    -NetworkName $ServerNetworkName `
                    -Name $ContainerServer1ID `
                    -Image $ContainerImage

                Write-Log "Creating floating IP: $ServerFloatingIpPoolName"
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    "PSUseDeclaredVarsMoreThanAssignments",
                    "ContrailFloatingIp",
                    Justification="It's actually used."
                )]
                $ContrailFloatingIp = $ContrailNM.AddFloatingIp($ContrailFloatingIpPool,
                                                                $ServerFloatingIpName,
                                                                $ServerFloatingIpAddress)

                $ContrailNM.AssignFloatingIpToAllPortsInNetwork($ContrailFloatingIp, $ContrailServerNetwork)
            }

            AfterEach {
                Write-Log "Deleting floating IP"
                if (Get-Variable ContrailFloatingIp -ErrorAction SilentlyContinue) {
                    $ContrailNM.RemoveFloatingIp($ContrailFloatingIp)
                }

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
                    Merge-Logs -LogSources (New-FileLogSource -Path (Get-ComputeLogsPath) -Sessions $Sessions)
                }
            }
        }

        BeforeAll {
            $VMs = Read-TestbedsConfig -Path $TestenvConfFile
            $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
            $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "ContrailNetwork",
                Justification="It's actually used."
            )]
            $SystemConfig = Read-SystemConfig -Path $TestenvConfFile

            $Sessions = New-RemoteSessions -VMs $VMs

            Initialize-PesterLogger -OutDir $LogDir

            Write-Log "Installing components on testbeds..."
            Install-Components -Session $Sessions[0]
            Install-Components -Session $Sessions[1]

            $ContrailNM = [ContrailNetworkManager]::new($OpenStackConfig, $ControllerConfig)
            $ContrailNM.EnsureProject($ControllerConfig.DefaultProject)

            $Testbed1Address = $VMs[0].Address
            $Testbed1Name = $VMs[0].Name
            Write-Log "Creating virtual router. Name: $Testbed1Name; Address: $Testbed1Address"
            $VRouter1Uuid = $ContrailNM.AddVirtualRouter($Testbed1Name, $Testbed1Address)
            Write-Log "Reported UUID of new virtual router: $VRouter1Uuid"

            $Testbed2Address = $VMs[1].Address
            $Testbed2Name = $VMs[1].Name
            Write-Log "Creating virtual router. Name: $Testbed2Name; Address: $Testbed2Address"
            $VRouter2Uuid = $ContrailNM.AddVirtualRouter($Testbed2Name, $Testbed2Address)
            Write-Log "Reported UUID of new virtual router: $VRouter2Uuid"
        }

        AfterAll {
            if (-not (Get-Variable Sessions -ErrorAction SilentlyContinue)) { return }

            if (Get-Variable "VRouter1Uuid" -ErrorAction SilentlyContinue) {
                Write-Log "Removing virtual router: $VRouter1Uuid"
                $ContrailNM.RemoveVirtualRouter($VRouter1Uuid)
                Remove-Variable "VRouter1Uuid"
            }
            if (Get-Variable "VRouter2Uuid" -ErrorAction SilentlyContinue) {
                Write-Log "Removing virtual router: $VRouter2Uuid"
                $ContrailNM.RemoveVirtualRouter($VRouter2Uuid)
                Remove-Variable "VRouter2Uuid"
            }

            Write-Log "Uninstalling components from testbeds..."
            Uninstall-Components -Session $Sessions[0]
            Uninstall-Components -Session $Sessions[1]

            Remove-PSSession $Sessions
        }
    }
}
