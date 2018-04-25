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

. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

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

    Write-Log "Created network id: $NetworkID"
}

function Test-Ping {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $SrcContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerIP
    )

    Write-Log "Container $SrcContainerName is pinging $DstContainerName..."
    $Res = Invoke-Command -Session $Session -ScriptBlock {
        docker exec $Using:SrcContainerName powershell "ping $Using:DstContainerIP; `$LASTEXITCODE;"
    }
    $Output = $Res[0..($Res.length - 2)]
    Write-Log "Ping output: $Output"
    return $Res[-1]
}

function Test-TCP {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $SrcContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerIP
    )

    Write-Log "Container $SrcContainerName is sending HTTP request to $DstContainerName..."
    $Res = Invoke-Command -Session $Session -ScriptBlock {
        docker exec $Using:SrcContainerName powershell "Invoke-WebRequest -Uri http://${Using:DstContainerIP}:8080/ -ErrorAction Continue; `$LASTEXITCODE"
    }
    $Output = $Res[0..($Res.length - 2)]
    Write-Log "Web request output: $Output"
    return $Res[-1]
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
        Write-Log "Tunnel usage statistics: Udp = $($VrfStats.MplsUdpPktCount), Gre = $($VrfStats.MplsGrePktCount), Vxlan = $($VrfStats.VxlanPktCount)"
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
        Write-Log "Tunnel usage statistics: Udp = $($VrfStats.MplsUdpPktCount), Gre = $($VrfStats.MplsGrePktCount), Vxlan = $($VrfStats.VxlanPktCount)"
        return $false
    } else {
        return $true
    }
}

Describe "Tunnelling with Agent tests" {
    Context "Tunneling" {
        It "ICMP - Ping between containers on separate compute nodes succeeds" {
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

        It "TCP - HTTP connection between containers on separate compute nodes succeeds" {
            Test-TCP `
                -Session $Sessions[1] `
                -SrcContainerName $Container2ID `
                -DstContainerName $Container1ID `
                -DstContainerIP $Container1NetInfo.IPAddress | Should Be 0

            # TODO: Uncomment these checks once we can actually control tunneling type.
            # Test-MPLSoGRE -Session $Sessions[0] | Should Be $true
            # Test-MPLSoGRE -Session $Sessions[1] | Should Be $true
        }

        It "UDP" -Pending {
            # TODO
        }
    }

    Context "MPLSoUDP" {
        # TODO: Enable this test once we can actually control tunneling type.
        It "ICMP - Ping between containers on separate compute nodes succeeds (MPLSoUDP)" -Pending {
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

        Write-Log "Creating virtual network: $NetworkName"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "ContrailNetwork",
            Justification="It's actually used."
        )]
        $ContrailNetwork = $ContrailNM.AddNetwork($null, $NetworkName, $Subnet)
    }

    AfterAll {
        if (-not (Get-Variable Sessions -ErrorAction SilentlyContinue)) { return }

        if(Get-Variable "VRouter1Uuid" -ErrorAction SilentlyContinue) {
            Write-Log "Removing virtual router: $VRouter1Uuid"
            $ContrailNM.RemoveVirtualRouter($VRouter1Uuid)
            Remove-Variable "VRouter1Uuid"
        }
        if(Get-Variable "VRouter2Uuid" -ErrorAction SilentlyContinue) {
            Write-Log "Removing virtual router: $VRouter2Uuid"
            $ContrailNM.RemoveVirtualRouter($VRouter2Uuid)
            Remove-Variable "VRouter2Uuid"
        }

        Write-Log "Uninstalling components from testbeds..."
        Uninstall-Components -Session $Sessions[0]
        Uninstall-Components -Session $Sessions[1]

        Write-Log "Deleting virtual network"
        if (Get-Variable ContrailNetwork -ErrorAction SilentlyContinue) {
            $ContrailNM.RemoveNetwork($ContrailNetwork)
        }

        Remove-PSSession $Sessions
    }

    BeforeEach {
        Initialize-ComputeNode -Session $Sessions[0] -Subnet $Subnet
        Initialize-ComputeNode -Session $Sessions[1] -Subnet $Subnet

        Write-Log "Creating containers"
        Write-Log "Creating container: $Container1ID"
        New-Container `
            -Session $Sessions[0] `
            -NetworkName $NetworkName `
            -Name $Container1ID `
            -Image $IisTcpTestDockerImage
        Write-Log "Creating container: $Container2ID"
        New-Container `
            -Session $Sessions[1] `
            -NetworkName $NetworkName `
            -Name $Container2ID

        Write-Log "Getting containers' NetAdapter Information"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "Container1NetInfo",
            Justification="It's actually used."
        )]
        $Container1NetInfo = Get-RemoteContainerNetAdapterInformation `
            -Session $Sessions[0] -ContainerID $Container1ID
        $IP = $Container1NetInfo.IPAddress
        Write-Log "IP of ${Container1ID}: $IP"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "Container2NetInfo",
            Justification="It's actually used."
        )]
        $Container2NetInfo = Get-RemoteContainerNetAdapterInformation `
            -Session $Sessions[1] -ContainerID $Container2ID
            $IP = $Container2NetInfo.IPAddress
            Write-Log "IP of ${Container2ID}: $IP"
    }

    AfterEach {
        try {
            Write-Log "Removing all containers"
            Remove-AllContainers -Sessions $Sessions
    
            Clear-TestConfiguration -Session $Sessions[0] -SystemConfig $SystemConfig
            Clear-TestConfiguration -Session $Sessions[1] -SystemConfig $SystemConfig
        } finally {
            Merge-Logs -LogSources (New-LogSource -Path (Get-ComputeLogsPath) -Sessions $Sessions)
        }
    }
}
