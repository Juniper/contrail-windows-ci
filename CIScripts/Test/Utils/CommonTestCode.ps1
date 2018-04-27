. $PSScriptRoot\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\PesterLogger\PesterLogger.ps1

class NetAdapterMacAddresses {
    [string] $MACAddress;
    [string] $MACAddressWindows;
}

class NetAdapterInformation : NetAdapterMacAddresses {
    [int] $IfIndex;
    [string] $IfName;
}

class ContainerNetAdapterInformation : NetAdapterInformation {
    [string] $AdapterShortName;
    [string] $AdapterFullName;
    [string] $IPAddress;
}

class VMNetAdapterInformation : NetAdapterMacAddresses {
    [string] $GUID;
}

function Get-RemoteNetAdapterInformation {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $AdapterName)

    $NetAdapterInformation = Invoke-Command -Session $Session -ScriptBlock {
        $Res = Get-NetAdapter -IncludeHidden -Name $Using:AdapterName | Select-Object ifName,MacAddress,ifIndex

        return @{
            IfIndex = $Res.IfIndex;
            IfName = $Res.ifName;
            MACAddress = $Res.MacAddress.Replace("-", ":").ToLower();
            MACAddressWindows = $Res.MacAddress.ToLower();
        }
    }

    return [NetAdapterInformation] $NetAdapterInformation
}

function Get-RemoteVMNetAdapterInformation {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $VMName,
           [Parameter(Mandatory = $true)] [string] $AdapterName)

    $NetAdapterInformation = Invoke-Command -Session $Session -ScriptBlock {
        $NetAdapter = Get-VMNetworkAdapter -VMName $Using:VMName -Name $Using:AdapterName
        $MacAddress = $NetAdapter.MacAddress -Replace '..(?!$)', '$&-'
        $GUID = $NetAdapter.Id.ToLower().Replace('microsoft:', '').Replace('\', '--')

        return @{
            MACAddress = $MacAddress.Replace("-", ":");
            MACAddressWindows = $MacAddress;
            GUID = $GUID
        }
    }

    return [VMNetAdapterInformation] $NetAdapterInformation
}

function Get-RemoteContainerNetAdapterInformation {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $ContainerID)

    $Adapter = Invoke-Command -Session $Session -ScriptBlock {

        $RemoteCommand = {
            $GetIPAddress = { ($_ | Get-NetIPAddress -AddressFamily IPv4).IPAddress }
            $Fields = 'ifIndex', 'ifName', 'Name', 'MacAddress', @{L='IPAddress'; E=$GetIPAddress}
            $Adapter = (Get-NetAdapter -Name 'vEthernet (Container NIC *)')[0]
            $Adapter | Select-Object $Fields | ConvertTo-Json
        }.toString()

        docker exec $Using:ContainerID powershell $RemoteCommand
    } | ConvertFrom-Json

    $Ret = @{
        ifIndex = $Adapter.ifIndex
        ifName = $Adapter.ifName
        AdapterFullName = $Adapter.Name
        AdapterShortName = [regex]::new('vEthernet \((.*)\)').Replace($Adapter.Name, '$1')
        MacAddressWindows = $Adapter.MacAddress.ToLower()
        IPAddress = $Adapter.IPAddress
    }

    $Ret.MacAddress = $Ret.MacAddressWindows.Replace('-', ':')

    return [ContainerNetAdapterInformation] $Ret
}

function Get-VrfStats {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    $VrfStats = Invoke-Command -Session $Session -ScriptBlock {
        $vrfstatsOutput = $(vrfstats --get 2)
        $mplsUdpPktCount = [regex]::new("Udp Mpls Tunnels ([0-9]+)").Match($vrfstatsOutput[3]).Groups[1].Value
        $mplsGrePktCount = [regex]::new("Gre Mpls Tunnels ([0-9]+)").Match($vrfstatsOutput[3]).Groups[1].Value
        $vxlanPktCount = [regex]::new("Vxlan Tunnels ([0-9]+)").Match($vrfstatsOutput[3]).Groups[1].Value
        return @{
            MplsUdpPktCount = $mplsUdpPktCount
            MplsGrePktCount = $mplsGrePktCount
            VxlanPktCount = $vxlanPktCount
        }
    }
    return $VrfStats
}

function Initialize-MPLSoGRE {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session1,
        [Parameter(Mandatory = $true)] [PSSessionT] $Session2,
        [Parameter(Mandatory = $true)] [string] $Container1ID,
        [Parameter(Mandatory = $true)] [string] $Container2ID,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    function Initialize-VRouterStructures {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [NetAdapterInformation] $ThisVMNetInfo,
               [Parameter(Mandatory = $true)] [NetAdapterInformation] $OtherVMNetInfo,
               [Parameter(Mandatory = $true)] [NetAdapterInformation] $ThisVHostInfo,
               [Parameter(Mandatory = $true)] [ContainerNetAdapterInformation] $ThisContainerNetInfo,
               [Parameter(Mandatory = $true)] [ContainerNetAdapterInformation] $OtherContainerNetInfo,
               [Parameter(Mandatory = $true)] [string] $ThisIPAddress,
               [Parameter(Mandatory = $true)] [string] $OtherIPAddress)

        Invoke-Command -Session $Session -ScriptBlock {
            vif --add $Using:ThisVMNetInfo.IfName --mac $Using:ThisVMNetInfo.MacAddress --vrf 0 --type physical
            vif --add $Using:ThisVHostInfo.IfName --mac $Using:ThisVHostInfo.MacAddress --vrf 0 --type vhost --xconnect $Using:ThisVMNetInfo.IfName
            vif --add $Using:ThisContainerNetInfo.IfName --mac $Using:ThisContainerNetInfo.MACAddress --vrf 1 --type virtual

            nh --create 4 --vrf 0 --type 1 --oif $Using:ThisVHostInfo.IfIndex
            nh --create 3 --vrf 1 --type 2 --el2 --oif $Using:ThisContainerNetInfo.IfIndex
            nh --create 2 --vrf 0 --type 3 --oif $Using:ThisVMNetInfo.IfIndex `
                --dmac $Using:OtherVMNetInfo.MACAddress --smac $Using:ThisVMNetInfo.MACAddress `
                --dip $Using:OtherIPAddress --sip $Using:ThisIPAddress

            mpls --create 10 --nh 3

            rt -c -v 1 -f 1 -e $Using:OtherContainerNetInfo.MACAddress -n 2 -t 10 -x 0x07
            rt -c -v 0 -f 0 -p $Using:ThisIPAddress -l 32 -n 4 -x 0x0f
        }
    }

    Write-Log "Getting VM NetAdapter Information"
    $VM1NetInfo = Get-RemoteNetAdapterInformation -Session $Session1 -AdapterName $SystemConfig.AdapterName
    $VM2NetInfo = Get-RemoteNetAdapterInformation -Session $Session2 -AdapterName $SystemConfig.AdapterName

    Write-Log "Getting VM vHost NetAdapter Information"
    $VM1VHostInfo = Get-RemoteNetAdapterInformation -Session $Session1 -AdapterName $SystemConfig.VHostName
    $VM2VHostInfo = Get-RemoteNetAdapterInformation -Session $Session2 -AdapterName $SystemConfig.VHostName

    Write-Log "Getting Containers NetAdapter Information"
    $Container1NetInfo = Get-RemoteContainerNetAdapterInformation -Session $Session1 -ContainerID $Container1ID
    $Container2NetInfo = Get-RemoteContainerNetAdapterInformation -Session $Session2 -ContainerID $Container2ID

    Write-Log "Initializing vRouter structures"
    # IPs of logical routers. They do not have to be IPs of the VMs.
    $VM1LogicalRouterIPAddress = "192.168.3.101"
    $VM2LogicalRouterIPAddress = "192.168.3.102"

    Initialize-VRouterStructures -Session $Session1 -ThisVMNetInfo $VM1NetInfo -OtherVMNetInfo $VM2NetInfo `
        -ThisContainerNetInfo $Container1NetInfo -OtherContainerNetInfo $Container2NetInfo -ThisVHostInfo $VM1VHostInfo `
        -ThisIPAddress $VM1LogicalRouterIPAddress -OtherIPAddress $VM2LogicalRouterIPAddress

    Initialize-VRouterStructures -Session $Session2 -ThisVMNetInfo $VM2NetInfo -OtherVMNetInfo $VM1NetInfo `
        -ThisContainerNetInfo $Container2NetInfo -OtherContainerNetInfo $Container1NetInfo -ThisVHostInfo $VM2VHostInfo `
        -ThisIPAddress $VM2LogicalRouterIPAddress -OtherIPAddress $VM1LogicalRouterIPAddress

    Write-Log "Executing netsh"
    Invoke-Command -Session $Session1 -ScriptBlock {
        $ContainerAdapterName = $Using:Container1NetInfo.AdapterFullName
        docker exec $Using:Container1ID netsh interface ipv4 add neighbors "$ContainerAdapterName" `
            $Using:Container2NetInfo.IPAddress $Using:Container2NetInfo.MACAddressWindows
    } | Out-Null
    Invoke-Command -Session $Session2 -ScriptBlock {
        $ContainerAdapterName = $Using:Container2NetInfo.AdapterFullName
        docker exec $Using:Container2ID netsh interface ipv4 add neighbors "$ContainerAdapterName" `
            $Using:Container1NetInfo.IPAddress $Using:Container1NetInfo.MACAddressWindows
    } | Out-Null

    return $Container1NetInfo.IPAddress, $Container2NetInfo.IPAddress
}

function Assert-PingSucceeded {
    Param ([Parameter(Mandatory = $true)] [Object[]] $Output)
    $ErrorMessage = "Ping failed. EXPECTED: Ping succeeded."
    Foreach ($Line in $Output) {
        if ($Line -match ", Received = (?<NumOfReceivedPackets>[\d]+),[.]*") {
            if ($matches.NumOfReceivedPackets -gt 0) {
                return
            } else {
                throw $ErrorMessage
            }
        }
    }
    throw $ErrorMessage
}

function Ping-Container {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $ContainerName,
           [Parameter(Mandatory = $true)] [string] $IP)
    $PingOutput = Invoke-Command -Session $Session -ScriptBlock {
        & docker exec $Using:ContainerName ping $Using:IP -n 10 -w 500
    }

    Assert-PingSucceeded -Output $PingOutput
}
