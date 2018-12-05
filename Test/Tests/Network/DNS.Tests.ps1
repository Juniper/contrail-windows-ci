Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs",
    [Parameter(Mandatory=$false)] [bool] $PrepareEnv = $true,
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Init.ps1

. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1

. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\Utils\WinContainers\Containers.ps1
. $PSScriptRoot\..\..\Utils\NetAdapterInfo\RemoteContainer.ps1
. $PSScriptRoot\..\..\Utils\ContrailNetworkManager.ps1

. $PSScriptRoot\..\..\Utils\MultiNode\ContrailMultiNodeProvisioning.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Initialize.ps1
. $PSScriptRoot\..\..\Utils\DockerNetwork\DockerNetwork.ps1

. $PSScriptRoot\..\..\Utils\ComputeNode\Configuration.ps1
. $PSScriptRoot\..\..\Utils\DockerNetwork\DockerNetwork.ps1

. $PSScriptRoot\..\..\Utils\ContrailAPI_New\DNSServer.ps1
. $PSScriptRoot\..\..\Utils\ContrailAPI_New\DNSRecord.ps1
. $PSScriptRoot\..\..\Utils\ContrailAPI_New\Ipam.ps1
. $PSScriptRoot\..\..\Utils\ContrailAPI_New\VirtualNetwork.ps1

$ContainersIDs = @("jolly-lumberjack","juniper-tree")

$Subnet = [SubnetConfiguration]::new(
    "10.0.5.0",
    24,
    "10.0.5.1",
    "10.0.5.19",
    "10.0.5.83"
)
$Network = [Network]::New("testnet12", $Subnet)

$TenantDNSServerAddress = "10.0.5.80"

$VirtualDNSServer = [DNSServer]::New("CreatedForTest")

$VirtualDNSrecords = @([DNSRecord]::New('vnone', $VirtualDNSServer.GetFQName(), "vdnsrecord-nonetest", "1.1.1.1", "A"),
                       [DNSRecord]::New('vdefa', $VirtualDNSServer.GetFQName(), "vdnsrecord-defaulttest", "1.1.1.2", "A"),
                       [DNSRecord]::New('vvirt', $VirtualDNSServer.GetFQName(), "vdnsrecord-virtualtest", "1.1.1.3", "A"),
                       [DNSRecord]::New('vtena', $VirtualDNSServer.GetFQName(), "vdnsrecord-tenanttest", "1.1.1.4", "A"))

$DefaultDNSrecords = @([DNSRecord]::New('vnone', @(), "defaultrecord-nonetest.com", "3.3.3.1", "A"),
                       [DNSRecord]::New('vdefa', @(), "defaultrecord-defaulttest.com", "3.3.3.2", "A"),
                       [DNSRecord]::New('vvirt', @(), "defaultrecord-virtualtest.com", "3.3.3.3", "A"),
                       [DNSRecord]::New('vtena', @(), "defaultrecord-tenanttest.com", "3.3.3.4", "A"))

# This function is used to generate command
# that will be passed to docker exec.
# $Hostname will be substituted.
function Resolve-DNSLocally {
    $resolved = (Resolve-DnsName -Name $Hostname -Type A -ErrorAction SilentlyContinue)

    if($error.Count -eq 0) {
        Write-Host "found"
        $resolved[0].IPAddress
    } else {
        Write-Host "error"
        $error[0].CategoryInfo.Category
    }
}
$ResolveDNSLocallyCommand = (${function:Resolve-DNSLocally} -replace "`n|`r", ";")

function Start-Container {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [string] $ContainerID,
        [Parameter(Mandatory=$true)] [string] $ContainerImage,
        [Parameter(Mandatory=$true)] [string] $NetworkName,
        [Parameter(Mandatory=$false)] [string] $IP
    )

    Write-Log "Creating container: $ContainerID"
    New-Container `
        -Session $Session `
        -NetworkName $NetworkName `
        -Name $ContainerID `
        -Image $ContainerImage `
        -IP $IP

    Write-Log "Getting container NetAdapter Information"
    $ContainerNetInfo = Get-RemoteContainerNetAdapterInformation `
        -Session $Session -ContainerID $ContainerID
    $IP = $ContainerNetInfo.IPAddress
    Write-Log "IP of $ContainerID : $IP"

    return $IP
}

function Start-DNSServerOnTestBed {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )
    Write-Log "Starting Test DNS Server on test bed..."
    $DefaultDNSServerDir = "C:\DNS_Server"
    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Force $Using:DefaultDNSServerDir | Out-Null
        New-Item "$($Using:DefaultDNSServerDir + '\zones')" -Type File -Force
        foreach($Record in $Using:DefaultDNSrecords) {
            Add-Content -Path "$($Using:DefaultDNSServerDir + '\zones')" -Value "$($Record.HostName)    $($Record.Type)    $($Record.Data)"
        }
    }

    Copy-Item -ToSession $Session -Path ($DockerfilesPath + "python-dns\dnserver.py") -Destination $DefaultDNSServerDir
    Invoke-Command -Session $Session -ScriptBlock {
        $env:ZONE_FILE = "$($Using:DefaultDNSServerDir + '\zones')"
        Start-Process -FilePath "python" -ArgumentList "$($Using:DefaultDNSServerDir + '\dnserver.py')"
    }
}

function Set-DNSServerAddressOnTestBed {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $ClientSession,
        [Parameter(Mandatory=$true)] [PSSessionT] $ServerSession
    )
    $DefaultDNSServerAddress = Invoke-Command -Session $ServerSession -ScriptBlock {
        Get-NetIPAddress -InterfaceAlias "Ethernet0" | Where-Object { $_.AddressFamily -eq 2 } | Select-Object -ExpandProperty IPAddress
    }
    Write-Log "Setting default DNS Server on test bed for: $DefaultDNSServerAddress..."
    $OldDNSs = Invoke-Command -Session $ClientSession -ScriptBlock {
        Get-DnsClientServerAddress -InterfaceAlias "Ethernet0" | Where-Object {$_.AddressFamily -eq 2} | Select-Object -ExpandProperty ServerAddresses
    }
    Invoke-Command -Session $ClientSession -ScriptBlock {
        Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses $Using:DefaultDNSServerAddress
    }

    return $OldDNSs
}

function Resolve-DNS {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $ContainerName,
        [Parameter(Mandatory=$true)] [String] $Hostname
    )

    $Command = $ResolveDNSLocallyCommand -replace '\$Hostname', ('"'+$Hostname+'"')

    $Result = (Invoke-Command -Session $Session -ScriptBlock {
        docker exec $Using:ContainerName powershell $Using:Command
    }).Split([Environment]::NewLine)

    Write-Log "Resolving effect: $($Result[0]) - $($Result[1])"

    if($Result[0] -eq "error") {
        return @{"error" = $Result[1]; "result" = $null}
    }

    return @{"error" = $null; "result" = $Result[1]}
}

function ResolveCorrectly {
    Param (
        [Parameter(Mandatory=$true)] [String] $Hostname,
        [Parameter(Mandatory=$false)] [String] $IP = "Any"
    )

    Write-Log "Trying to resolve host '$Hostname', expecting ip '$IP'"

    $result = Resolve-DNS -Session $MultiNode.Sessions[0] `
        -ContainerName $ContainersIDs[0] -Hostname $Hostname

    if((-not $result.error)) {
        if(($IP -eq "Any") -or ($result.result -eq $IP)) {
            return $true
        }
    }
    return $false
}

function ResolveWithError {
    Param (
        [Parameter(Mandatory=$true)] [String] $Hostname,
        [Parameter(Mandatory=$true)] [String] $ErrorType
    )

    Write-Log "Trying to resolve host '$Hostname', expecting error '$ErrorType'"

    $result = Resolve-DNS -Session $MultiNode.Sessions[0] `
        -ContainerName $ContainersIDs[0] -Hostname $Hostname
    return (($result.error -eq $ErrorType) -and (-not $result.result))
}

Test-WithRetries 1 {
    Describe "DNS tests" -Tag "Smoke" {
        BeforeAll {
            Initialize-PesterLogger -OutDir $LogDir
            $MultiNode = New-MultiNodeSetup -TestenvConfFile $TestenvConfFile

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "VirtualNetworkRepo",
                Justification = "It's actually used."
            )]
            $VirtualNetworkRepo = [ContrailRepo]::new($MultiNode.NM)
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "IPAMRepo",
                Justification = "It's actually used."
            )]
            $IPAMRepo = [ContrailRepo]::New($MultiNode.NM)
            $DNSServerRepo = [ContrailRepo]::New($MultiNode.NM)
            $DNSRecordRepo = [ContrailRepo]::New($MultiNode.NM)

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "FileLogSources",
                Justification="It's actually used in 'AfterEach' block."
            )]
            $FileLogSources = New-ComputeNodeLogSources -Sessions $MultiNode.Sessions
            Start-DNSServerOnTestBed -Session $MultiNode.Sessions[1]

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "OldDNSs",
                Justification="It's actually used."
            )]
            $OldDNSs = Set-DNSServerAddressOnTestBed `
                           -ClientSession $MultiNode.Sessions[0] `
                           -ServerSession $MultiNode.Sessions[1]

            Write-Log "Creating Virtual DNS Server in Contrail..."
            $DNSServerRepo.AddOrReplace($VirtualDNSServer)
            foreach($DNSRecord in $VirtualDNSrecords) {
                $DNSRecordRepo.Add($DNSRecord)
            }

            if ($PrepareEnv) {
                Write-Log "Initializing Contrail services on test beds..."
                foreach($Session in $MultiNode.Sessions) {
                    Initialize-ComputeNode `
                        -Session $Session `
                        -Configs $MultiNode.Configs `
                }
            }

            Write-Log "Creating virtual network: $($Network.Name)"
            $VirtualNetworkSubnet = [Subnet]::new(
                $Subnet.IpPrefix,
                $Subnet.IpPrefixLen,
                $Subnet.DefaultGateway,
                $Subnet.AllocationPoolsStart,
                $Subnet.AllocationPoolsEnd)
            $VirtualNetwork = [VirtualNetwork]::new($Network.Name, $MultiNode.NM.DefaultTenantName, $VirtualNetworkSubnet)
            $Response = $VirtualNetworkRepo.AddOrReplace($VirtualNetwork)
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                "PSUseDeclaredVarsMoreThanAssignments",
                "ContrailNetwork",
                Justification = "It's actually used."
            )]
            $ContrailNetwork = $Response.'virtual-network'.'uuid'
        }

        function BeforeEachContext {
            Param (
                [Parameter(Mandatory=$true)] [IPAMDNSSettings] $DNSSettings
            )
            $IPAM = [IPAM]::New()
            $IPAM.DNSSettings = $DNSSettings
            $IPAMRepo.Set($IPAM)

            foreach($Session in $MultiNode.Sessions) {
                Initialize-DockerNetworks `
                    -Session $Session `
                    -Networks @($Network) `
                    -Configs $MultiNode.Configs
            }


            Start-Container -Session $MultiNode.Sessions[0] `
                -ContainerID $ContainersIDs[0] `
                -ContainerImage "microsoft/windowsservercore" `
                -NetworkName $Network.Name
        }

        function AfterEachContext {
            Invoke-Command -ErrorAction SilentlyContinue {
                Merge-Logs -LogSources (
                    (New-ContainerLogSource -Sessions $MultiNode.Sessions[0] -ContainerNames $ContainersIDs[0]),
                    (New-ContainerLogSource -Sessions $MultiNode.Sessions[1] -ContainerNames $ContainersIDs[1])
                )

                Write-Log "Removing all containers and docker networks"
                Remove-AllContainers -Sessions $MultiNode.Sessions
                Remove-AllUnusedDockerNetworks -Session $MultiNode.Sessions[0]
                Remove-AllUnusedDockerNetworks -Session $MultiNode.Sessions[1]
            }
        }

        AfterAll {
            if (Get-Variable "ContrailNetwork" -ErrorAction SilentlyContinue) {
                Write-Log "Deleting virtual network"
                $VirtualNetworkRepo.RemoveWithDependencies($VirtualNetwork) | Out-Null
            }

            if (Get-Variable "MultiNode" -ErrorAction SilentlyContinue) {
                if ($PrepareEnv) {
                    foreach($Session in $MultiNode.Sessions) {
                        Clear-ComputeNode `
                            -Session $Session `
                            -SystemConfig $MultiNode.Configs.System
                    }
                    Clear-Logs -LogSources $FileLogSources
                }

                Write-Log "Removing Virtual DNS Server from Contrail..."
                $DNSServerRepo.RemoveWithDependencies($VirtualDNSServer)

                if (Get-Variable "OldDNSs" -ErrorAction SilentlyContinue) {
                    Write-Log "Restoring old DNS servers on test bed..."
                    Invoke-Command -Session $MultiNode.Sessions[0] -ScriptBlock {
                        Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses $Using:OldDNSs
                    }
                }

                Remove-MultiNodeSetup -MultiNode $MultiNode
                Remove-Variable "MultiNode"
            }
        }

        AfterEach {
            Merge-Logs -DontCleanUp -LogSources $FileLogSources
        }

        Context "DNS mode none" {
            BeforeAll { BeforeEachContext -DNSSetting ([NoneDNSSettings]::New()) }

            AfterAll { AfterEachContext }

            It "timeouts resolving juniper.net" {
                ResolveWithError `
                    -Hostname "Juniper.net" `
                    -ErrorType "OperationTimeout" `
                    | Should -BeTrue
            }
        }

        Context "DNS mode default" {
            BeforeAll { BeforeEachContext -DNSSetting ([DefaultDNSSettings]::New()) }

            AfterAll { AfterEachContext }

            It "doesn't resolve juniper.net" {
                ResolveWithError `
                    -Hostname "Juniper.net" `
                    -ErrorType "ResourceUnavailable" `
                    | Should -BeTrue
            }

            It "doesn't resolve virtual DNS" {
                ResolveWithError `
                    -Hostname "vdnsrecord-defaulttest.default-domain" `
                    -ErrorType "ResourceUnavailable" `
                    | Should -BeTrue
            }

            It "resolves default DNS server" {
                ResolveCorrectly `
                    -Hostname "defaultrecord-defaulttest.com" `
                    -IP "3.3.3.2" `
                    | Should -BeTrue
            }
        }

        Context "DNS mode virtual" {
            BeforeAll { BeforeEachContext -DNSSetting ([VirtualDNSSettings]::New($VirtualDNSServer.GetFQName())) }

            AfterAll { AfterEachContext }

            It "resolves juniper.net" {
                ResolveCorrectly `
                    -Hostname " juniper.net" `
                    | Should -BeTrue
            }

            It "resolves virtual DNS" {
                ResolveCorrectly `
                    -Hostname "vdnsrecord-virtualtest.default-domain" `
                    -IP "1.1.1.3" `
                    | Should -BeTrue
            }

            It "doesn't resolve default DNS server" {
                ResolveWithError `
                    -Hostname "defaultrecord-virtualtest.com" `
                    -ErrorType "ResourceUnavailable" `
                    | Should -BeTrue
            }
        }

        Context "DNS mode tenant" {
            BeforeAll {
                BeforeEachContext -DNSSetting ([TenantDNSSettings]::New(@($TenantDNSServerAddress)))

                Start-Container `
                    -Session $MultiNode.Sessions[1] `
                    -ContainerID $ContainersIDs[1] `
                    -ContainerImage "python-dns" `
                    -NetworkName $Network.Name `
                    -IP $TenantDNSServerAddress
            }

            AfterAll { AfterEachContext }

            It "doesn't resolve juniper.net" {
                ResolveWithError `
                    -Hostname "juniper.net" `
                    -ErrorType "ResourceUnavailable" `
                    | Should -BeTrue
            }

            It "doesn't resolve virtual DNS" {
                ResolveWithError `
                    -Hostname "vdnsrecord-tenanttest.default-domain" `
                    -ErrorType "ResourceUnavailable" `
                    | Should -BeTrue
            }

            It "doesn't resolve default DNS server" {
                ResolveWithError `
                    -Hostname "defaultrecord-tenanttest.com" `
                    -ErrorType "ResourceUnavailable" `
                    | Should -BeTrue
            }

            It "resolves tenant DNS" {
                ResolveCorrectly `
                    -Hostname "tenantrecord-tenanttest.com" `
                    -IP "2.2.2.4" `
                    | Should -BeTrue
            }
        }
    }
}
