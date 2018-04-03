Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs"
)

. $PSScriptRoot\..\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\Common\Init.ps1
. $PSScriptRoot\..\..\Utils\ComponentsInstallation.ps1
. $PSScriptRoot\..\..\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\..\Testenv\Testbed.ps1
. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1
. $PSScriptRoot\..\..\Utils\CommonTestCode.ps1
. $PSScriptRoot\..\..\Utils\DockerImageBuild.ps1

$IisTcpTestDockerImage = "iis-tcptest"
$Container1ID = "jolly-lumberjack"
$Container2ID = "juniper-tree"
$NetworkName = "testnet12"
$Subnet = [SubnetConfiguration]::new(
    "10.0.5.0",
    24,
    "10.0.5.1",
    "10.0.5.19",
    "10.0.5.83"
)

function Initialize-ComputeNode {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [SubnetConfiguration] $Subnet
    )

    Initialize-ComputeServices -Session $Session `
        -SystemConfig $SystemConfig `
        -OpenStackConfig $OpenStackConfig `
        -ControllerConfig $ControllerConfig

    $NetworkID = New-DockerNetwork -Session $Session `
        -TenantName $ControllerConfig.DefaultProject `
        -Name $NetworkName `
        -Subnet "$( $Subnet.IpPrefix )/$( $Subnet.IpPrefixLen )"

    Write-Host "Created network id: $NetworkID"
}

function Test-Ping {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $SrcContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerIP
    )

    Write-Host "Container $SrcContainerName is pinging $DstContainerName..."
    $Res = Invoke-Command -Session $Session -ScriptBlock {
        docker exec $Using:SrcContainerName powershell "ping $Using:DstContainerIP; `$LASTEXITCODE;"
    }
    $Output = $Res[0..($Res.length - 2)]
    Write-Host "Ping output: $Output"
    return $Res[-1]
}

function Test-TCP {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $SrcContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerIP
    )

    Write-Host "Container $SrcContainerName is sending HTTP request to $DstContainerName..."
    $Res = Invoke-Command -Session $Session -ScriptBlock {
        docker exec $Using:SrcContainerName powershell "Invoke-WebRequest -Uri http://${Using:DstContainerIP}:8080/ -UseBasicParsing -ErrorAction Continue; `$LASTEXITCODE"
    }
    $Output = $Res[0..($Res.length - 2)]
    Write-Host "Web request output: $Output"
    return $Res[-1]
}

function Remove-IISDockerImage {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    Invoke-Command -Session $Session {
        docker image rm $Using:IisTcpTestDockerImage -f 2>$null
    }
}

function Install-Components {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    Install-Extension -Session $Session
    Install-DockerDriver -Session $Session
    Install-Agent -Session $Session
    Install-Utils -Session $Session
}

function Uninstall-Components {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    Uninstall-Utils -Session $Session
    Uninstall-Agent -Session $Session
    Uninstall-DockerDriver -Session $Session
    Uninstall-Extension -Session $Session
}

function Test-MPLSoGRE {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $VrfStats = Get-VrfStats -Session $Session
    if (($VrfStats.MplsGrePktCount -eq 0) -or ($VrfStats.MplsUdpPktCount -ne 0) -or ($VrfStats.VxlanPktCount -ne 0)) {
        Write-Host "Tunnel usage statistics: Udp = $($VrfStats.MplsUdpPktCount), Gre = $($VrfStats.MplsGrePktCount), Vxlan = $($VrfStats.VxlanPktCount)"
        return $false
    } else {
        return $true
    }
}

function Test-MPLSoUDP {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $VrfStats = Get-VrfStats -Session $Session
    if (($VrfStats.MplsGrePktCount -ne 0) -or ($VrfStats.MplsUdpPktCount -eq 0) -or ($VrfStats.VxlanPktCount -ne 0)) {
        Write-Host "Tunnel usage statistics: Udp = $($VrfStats.MplsUdpPktCount), Gre = $($VrfStats.MplsGrePktCount), Vxlan = $($VrfStats.VxlanPktCount)"
        return $false
    } else {
        return $true
    }
}

function Start-UDPEchoServerInContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $ContainerName,
        [Parameter(Mandatory=$true)] [Int16] $ServerPort,
        [Parameter(Mandatory=$true)] [Int16] $ClientPort
    )
    $UDPEchoServerCommand = ( `
    '$SendPort = {0};' + `
    '$RcvPort = {1};' + `
    '$IPEndpoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, $RcvPort);' + `
    '$UDPSocket = New-Object System.Net.Sockets.UdpClient($IPEndpoint);' + `
    '$RemoteIPEndpoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, 0);' + `
    'while($true) {{' + `
    '    $Payload = $UDPSocket.Receive([ref]$RemoteIPEndpoint);' + `
    '    $RemoteIPEndpoint.Port = $SendPort;' + `
    '    $Message = [Text.Encoding]::UTF8.GetString($Payload);' + `
    '    $UDPSocket.Send($Payload, $Payload.Length, $RemoteIPEndpoint);' + `
    '}}') -f $ClientPort, $ServerPort

    Invoke-Command -Session $Session -ScriptBlock {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "UDPEchoServerJob",
            Justification="It's actually used."
        )]
        $UDPEchoServerJob = Start-Job -ScriptBlock {
            param($ContainerName, $UDPEchoServerCommand)
            docker exec $ContainerName powershell "$UDPEchoServerCommand"
        } -ArgumentList $Using:ContainerName, $Using:UDPEchoServerCommand
    }
}

function Stop-EchoServerInContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    Invoke-Command -Session $Session -ScriptBlock {
        $UDPEchoServerJob | Stop-Job | Out-Null
    }
}

function Start-UDPListenerInContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $ContainerName,
        [Parameter(Mandatory=$true)] [Int16] $ListenerPort
    )

    $UDPListenerCommand = ( `
    '$RemoteIPEndpoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, 0);' + `
    '$UDPRcvSocket = New-Object System.Net.Sockets.UdpClient {0};' + `
    '$Payload = $UDPRcvSocket.Receive([ref]$RemoteIPEndpoint);' + `
    '$Message = [Text.Encoding]::UTF8.GetString($Payload);' + `
    'return $Message') -f $ListenerPort

    Invoke-Command -Session $Session -ScriptBlock {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "UDPListenerJob",
            Justification="It's actually used."
        )]
        $UDPListenerJob = Start-Job -ScriptBlock {
            param($ContainerName, $UDPListenerCommand)
            & docker exec $ContainerName powershell "$UDPListenerCommand"
        } -ArgumentList $Using:ContainerName, $Using:UDPListenerCommand
    }
}

function Stop-UDPListenerInContainerAndFetchResult {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $ReceivedMessage = Invoke-Command -Session $Session -ScriptBlock {
        $UDPListenerJob | Wait-Job -Timeout 5
        $ReceivedMessage = Receive-Job -Job $UDPListenerJob
        return $ReceivedMessage
    }
    return $ReceivedMessage
}

function Send-UDPFromContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $ContainerName,
        [Parameter(Mandatory=$true)] [String] $Message,
        [Parameter(Mandatory=$true)] [String] $ListenerIP,
        [Parameter(Mandatory=$true)] [Int16] $ListenerPort,
        [Parameter(Mandatory=$true)] [Int16] $NumberOfAttempts,
        [Parameter(Mandatory=$true)] [Int16] $WaitSeconds
    )
    $UDPSendCommand = (
    '$EchoServerAddress = New-Object System.Net.IPEndPoint([IPAddress]::Parse(\"{0}\"), {1});' + `
    '$UDPSenderSocket = New-Object System.Net.Sockets.UdpClient 0;' + `
    '$Payload = [Text.Encoding]::UTF8.GetBytes(\"{2}\");' + `
    '1..{3} | ForEach-Object {{' + `
    '    $UDPSenderSocket.Send($Payload, $Payload.Length, $EchoServerAddress);' + `
    '    Start-Sleep -Seconds {4};' + `
    '}}') -f $ListenerIP, $ListenerPort, $Message, $NumberOfAttempts, $WaitSeconds

    $Output = Invoke-Command -Session $Session -ScriptBlock {
        docker exec $Using:ContainerName powershell "$Using:UDPSendCommand"
    }
    Write-Host "Send UDP output from remote session: $Output"
}

Describe "Tunnelling with Agent tests" {
    Context "Tunneling" {
        It "ICMP: Ping between containers on separate compute nodes succeeds" {
            Test-Ping `
                -Session $Sessions[0] `
                -SrcContainerName $Container1ID `
                -DstContainerName $Container2ID `
                -DstContainerIP $Container2NetInfo.IPAddress | Should Be 0

            Test-Ping `
                -Session $Sessions[1] `
                -SrcContainerName $Container2ID `
                -DstContainerName $Container1ID `
                -DstContainerIP $Container1NetInfo.IPAddress | Should Be 0

            # TODO: Uncomment these checks once we can actually control tunneling type.
            # Test-MPLSoGRE -Session $Sessions[0] | Should Be $true
            # Test-MPLSoGRE -Session $Sessions[1] | Should Be $true
        }

        It "TCP: HTTP connection between containers on separate compute nodes succeeds" {
            Test-TCP `
                -Session $Sessions[1] `
                -SrcContainerName $Container2ID `
                -DstContainerName $Container1ID `
                -DstContainerIP $Container1NetInfo.IPAddress | Should Be 0

            # TODO: Uncomment these checks once we can actually control tunneling type.
            # Test-MPLSoGRE -Session $Sessions[0] | Should Be $true
            # Test-MPLSoGRE -Session $Sessions[1] | Should Be $true
        }

        It "UDP" {
            $MyMessage = "We are Tungsten Fabric. We come in peace."
            $UDPServerPort = 1905
            $UDPClientPort = 1983

            Write-Host "Starting UDP Echo server on container $Container1ID ..."
            Start-UDPEchoServerInContainer `
                -Session $Sessions[0] `
                -ContainerName $Container1ID `
                -ServerPort $UDPServerPort `
                -ClientPort $UDPClientPort

            Write-Host "Starting UDP listener on container $Container2ID..."
            Start-UDPListenerInContainer `
                -Session $Sessions[1] `
                -ContainerName $Container2ID `
                -ListenerPort $UDPClientPort

            Write-Host "Sending UDP packet from container $Container2ID..."
            Send-UDPFromContainer `
                -Session $Sessions[1] `
                -ContainerName $Container2ID `
                -Message $MyMessage `
                -ListenerIP $Container1NetInfo.IPAddress `
                -ListenerPort $UDPServerPort `
                -NumberOfAttempts 3 `
                -WaitSeconds 1

            Write-Host "Fetching results from listener job..."
            $ReceivedMessage = Stop-UDPListenerInContainerAndFetchResult -Session $Sessions[1]
            Stop-EchoServerInContainer -Session $Sessions[0]

            Write-Host "Sent message: $MyMessage"
            Write-Host "Received message: $ReceivedMessage"
            $ReceivedMessage | Should Be $MyMessage

            # TODO: Uncomment these checks once we can actually control tunneling type.
            # Test-MPLSoGRE -Session $Sessions[0] | Should Be $true
            # Test-MPLSoGRE -Session $Sessions[1] | Should Be $true
        }
    }

    Context "MPLSoUDP" {
        # TODO: Enable this test once we can actually control tunneling type.
        It "ICMP: Ping between containers on separate compute nodes succeeds (MPLSoUDP)" -Pending {
            Test-Ping `
                -Session $Sessions[0] `
                -SrcContainerName $Container1ID `
                -DstContainerName $Container2ID `
                -DstContainerIP $Container2NetInfo.IPAddress | Should Be 0

            Test-Ping `
                -Session $Sessions[1] `
                -SrcContainerName $Container2ID `
                -DstContainerName $Container1ID `
                -DstContainerIP $Container1NetInfo.IPAddress | Should Be 0

            Test-MPLSoUDP -Session $Sessions[0] | Should Be $true
            Test-MPLSoUDP -Session $Sessions[1] | Should Be $true
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

        Write-Host "Installing iis-tcptest docker image on testbed..."
        Initialize-DockerImage -Session $Sessions[0] -DockerImageName $IisTcpTestDockerImage

        Write-Host "Installing components on testbeds..."
        Install-Components -Session $Sessions[0]
        Install-Components -Session $Sessions[1]

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "ContrailNM",
            Justification="It's actually used."
        )]
        $ContrailNM = [ContrailNetworkManager]::new($OpenStackConfig, $ControllerConfig)

        $ContrailNM.EnsureProject($ControllerConfig.DefaultProject)

        $Testbed1Address = $VMs[0].Address
        $Testbed1Name = $VMs[0].Name
        Write-Host "Creating virtual router. Name: $Testbed1Name; Address: $Testbed1Address"
        $VRouter1Uuid = $ContrailNM.AddVirtualRouter($Testbed1Name, $Testbed1Address)
        Write-Host "Reported UUID of new virtual router: $VRouter1Uuid"

        $Testbed2Address = $VMs[1].Address
        $Testbed2Name = $VMs[1].Name
        Write-Host "Creating virtual router. Name: $Testbed2Name; Address: $Testbed2Address"
        $VRouter2Uuid = $ContrailNM.AddVirtualRouter($Testbed2Name, $Testbed2Address)
        Write-Host "Reported UUID of new virtual router: $VRouter2Uuid"

        Write-Host "Creating virtual network: $NetworkName"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "ContrailNetwork",
            Justification="It's actually used."
        )]
        $ContrailNetwork = $ContrailNM.AddNetwork($null, $NetworkName, $Subnet)
    }

    AfterAll {
        if (-not (Get-Variable Sessions -ErrorAction SilentlyContinue)) { return }

        Write-Host "Removing iis-tcptest docker image from testbed..."
        Remove-IISDockerImage -Session $Sessions[0]

        if(Get-Variable "VRouter1Uuid" -ErrorAction SilentlyContinue) {
            Write-Host "Removing virtual router: $VRouter1Uuid"
            $ContrailNM.RemoveVirtualRouter($VRouter1Uuid)
            Remove-Variable "VRouter1Uuid"
        }
        if(Get-Variable "VRouter2Uuid" -ErrorAction SilentlyContinue) {
            Write-Host "Removing virtual router: $VRouter2Uuid"
            $ContrailNM.RemoveVirtualRouter($VRouter2Uuid)
            Remove-Variable "VRouter2Uuid"
        }

        Write-Host "Uninstalling components from testbeds..."
        Uninstall-Components -Session $Sessions[0]
        Uninstall-Components -Session $Sessions[1]

        Write-Host "Deleting virtual network"
        if (Get-Variable ContrailNetwork -ErrorAction SilentlyContinue) {
            $ContrailNM.RemoveNetwork($ContrailNetwork)
        }

        Remove-PSSession $Sessions
    }

    BeforeEach {
        Initialize-ComputeNode -Session $Sessions[0] -Subnet $Subnet
        Initialize-ComputeNode -Session $Sessions[1] -Subnet $Subnet

        Write-Host "Creating containers"
        Write-Host "Creating container: $Container1ID"
        New-Container `
            -Session $Sessions[0] `
            -NetworkName $NetworkName `
            -Name $Container1ID `
            -Image $IisTcpTestDockerImage
        Write-Host "Creating container: $Container2ID"
        New-Container `
            -Session $Sessions[1] `
            -NetworkName $NetworkName `
            -Name $Container2ID `
            -Image "microsoft/windowsservercore"

        Write-Host "Getting containers' NetAdapter Information"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "Container1NetInfo",
            Justification="It's actually used."
        )]
        $Container1NetInfo = Get-RemoteContainerNetAdapterInformation `
            -Session $Sessions[0] -ContainerID $Container1ID
        $IP = $Container1NetInfo.IPAddress
        Write-Host "IP of ${Container1ID}: $IP"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "Container2NetInfo",
            Justification="It's actually used."
        )]
        $Container2NetInfo = Get-RemoteContainerNetAdapterInformation `
            -Session $Sessions[1] -ContainerID $Container2ID
            $IP = $Container2NetInfo.IPAddress
            Write-Host "IP of ${Container2ID}: $IP"
    }

    AfterEach {
        Write-Host "Removing container $Container1ID..."
        Remove-Container -Session $Sessions[0] -NameOrId $Container1ID

        Write-Host "Removing container $Container2ID..."
        Remove-Container -Session $Sessions[1] -NameOrId $Container2ID

        Clear-TestConfiguration -Session $Sessions[0] -SystemConfig $SystemConfig
        Clear-TestConfiguration -Session $Sessions[1] -SystemConfig $SystemConfig
    }
}
