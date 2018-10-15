. $PSScriptRoot\ContrailAPI\FloatingIP.ps1
. $PSScriptRoot\ContrailAPI\FloatingIPPool.ps1
. $PSScriptRoot\ContrailAPI\NetworkPolicy.ps1
. $PSScriptRoot\ContrailAPI\VirtualNetwork.ps1
. $PSScriptRoot\ContrailAPI\VirtualRouter.ps1
. $PSScriptRoot\ContrailAPI\ConfigureDNS.ps1
. $PSScriptRoot\ContrailUtils.ps1
. $PSScriptRoot\ContrailAPI\GlobalVrouterConfig.ps1

class ContrailNetworkManager {
    [String] $AuthToken;
    [String] $ContrailUrl;
    [String] $DefaultTenantName;

    # We cannot add a type to the parameters,
    # because the class is parsed before the files are sourced.
    ContrailNetworkManager($OpenStackConfig, $ControllerConfig) {

        $this.ContrailUrl = $ControllerConfig.RestApiUrl()
        $this.DefaultTenantName = $ControllerConfig.DefaultProject

        $this.AuthToken = Get-AccessTokenFromKeystone `
            -AuthUrl $OpenStackConfig.AuthUrl() `
            -Username $OpenStackConfig.Username `
            -Password $OpenStackConfig.Password `
            -Tenant $OpenStackConfig.Project
    }

    [String] AddProject([String] $TenantName) {
        if (-not $TenantName) {
            $TenantName = $this.DefaultTenantName
        }

        return Add-ContrailProject `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -ProjectName $TenantName
    }

    EnsureProject([String] $TenantName) {
        if (-not $TenantName) {
            $TenantName = $this.DefaultTenantName
        }

        try {
            $this.AddProject($TenantName)
        }
        catch {
            if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
                throw
            }
        }
    }

    # TODO support multiple subnets per network
    # TODO return a class (perhaps use the class from MultiTenancy test?)
    # We cannot add a type to $SubnetConfig parameter,
    # because the class is parsed before the files are sourced.
    [String] AddOrReplaceNetwork([String] $TenantName, [String] $Name, $SubnetConfig) {
        if (-not $TenantName) {
            $TenantName = $this.DefaultTenantName
        }

        try {
            return Add-ContrailVirtualNetwork `
                -ContrailUrl $this.ContrailUrl `
                -AuthToken $this.AuthToken `
                -TenantName $TenantName `
                -NetworkName $Name `
                -SubnetConfig $SubnetConfig
        } catch {
            if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
                throw
            }

            $NetworkUuid = Get-ContrailVirtualNetworkUuidByName `
                -ContrailUrl $this.ContrailUrl `
                -AuthToken $this.AuthToken `
                -TenantName $TenantName `
                -NetworkName $Name

            $this.RemoveNetwork($NetworkUuid)

            return Add-ContrailVirtualNetwork `
                -ContrailUrl $this.ContrailUrl `
                -AuthToken $this.AuthToken `
                -TenantName $TenantName `
                -NetworkName $Name `
                -SubnetConfig $SubnetConfig
        }
    }

    RemoveNetwork([String] $Uuid) {
        Remove-ContrailVirtualNetwork `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -NetworkUuid $Uuid
    }

    [String] AddOrReplaceVirtualRouter([String] $RouterName, [String] $RouterIp) {
        try {
            return Add-ContrailVirtualRouter `
                -ContrailUrl $this.ContrailUrl `
                -AuthToken $this.AuthToken `
                -RouterName $RouterName `
                -RouterIp $RouterIp
        } catch {
            if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
                throw
            }

            $RouterUuid = Get-ContrailVirtualRouterUuidByName `
                -ContrailUrl $this.ContrailUrl `
                -AuthToken $this.AuthToken `
                -RouterName $RouterName

            $this.RemoveVirtualRouter($RouterUuid)

            return Add-ContrailVirtualRouter `
                -ContrailUrl $this.ContrailUrl `
                -AuthToken $this.AuthToken `
                -RouterName $RouterName `
                -RouterIp $RouterIp
        }
    }

    RemoveVirtualRouter([String] $RouterUuid) {
        Remove-ContrailVirtualRouter `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -RouterUuid $RouterUuid
    }

    SetEncapPriorities([String[]] $PrioritiesList) {
        # PrioritiesList is a list of (in any order) "MPLSoGRE", "MPLSoUDP", "VXLAN".
        Set-EncapPriorities `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -PrioritiesList $PrioritiesList
    }

    [String] AddFloatingIpPool([String] $TenantName, [String] $NetworkName, [String] $PoolName) {
        if (-not $TenantName) {
            $TenantName = $this.DefaultTenantName
        }

        return Add-ContrailFloatingIpPool `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -TenantName $TenantName `
            -NetworkName $NetworkName `
            -PoolName $PoolName
    }

    RemoveFloatingIpPool([String] $PoolUuid) {
        Remove-ContrailFloatingIpPool `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -PoolUuid $PoolUuid
    }

    [String] AddFloatingIp([String] $PoolUuid,
                           [String] $IPName,
                           [String] $IPAddress) {
        return Add-ContrailFloatingIp `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -PoolUuid $PoolUuid `
            -IPName $IPName `
            -IPAddress $IPAddress
    }

    AssignFloatingIpToAllPortsInNetwork([String] $IpUuid,
                                        [String] $NetworkUuid) {
        $PortFqNames = Get-ContrailVirtualNetworkPorts `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -NetworkUuid $NetworkUuid

        Set-ContrailFloatingIpPorts `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -IpUuid $IpUuid `
            -PortFqNames $PortFqNames
    }

    RemoveFloatingIp([String] $IpUuid) {
        Remove-ContrailFloatingIp `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -IpUuid $IpUuid
    }

    [String] AddPassAllPolicyOnDefaultTenant([String] $Name) {
        $TenantName = $this.DefaultTenantName

        return Add-ContrailPassAllPolicy `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -TenantName $TenantName `
            -Name $Name
    }

    RemovePolicy([String] $Uuid) {
        Remove-ContrailPolicy `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -Uuid $Uuid
    }

    AddPolicyToNetwork([String] $PolicyUuid,
                       [String] $NetworkUuid) {
        Add-ContrailPolicyToNetwork `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -PolicyUuid $PolicyUuid `
            -NetworkUuid $NetworkUuid
    }

    # Overloaded version for none or default mode
    SetIpamDNSMode([String[]] $IpamFQName,
                   [String] $DNSMode) {
        if($DNSMode -ceq 'tenant-dns-server' -or $DNSMode -ceq 'virtual-dns-server') {
            throw "When setting tenant or virtual DNS mode, you have to specify servers."
        }
        elseif(-not ($DNSMode -ceq 'none' -or $DNSMode -ceq 'default-dns-server')){
            throw "Not supported DNS mode: " + $DNSMode
        }
        Set-IpamDNSMode `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -IpamFQName $IpamFQName `
            -DNSMode $DNSMode
    }

    # Overloaded version for tenant dns mode
    SetIpamDNSMode([String[]] $IpamFQName,
                   [String] $DNSMode,
                   [String[]] $TenantServersIPAddresses) {
        if($DNSMode -cne 'tenant-dns-server') {
            throw "You shouldn't specify DNS server IP addresses for '" + $DNSMode + "' DNS mode."
        }
        Set-IpamDNSMode `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -IpamFQName $IpamFQName `
            -DNSMode $DNSMode `
            -TenantServersIPAddresses $TenantServersIPAddresses
    }

    # Overloaded version for virtual dns mode
    SetIpamDNSMode([String[]] $IpamFQName,
                   [String] $DNSMode,
                   [String] $VirtualServerName) {
        if($DNSMode -cne 'virtual-dns-server') {
            throw "You shouldn't specify DNS server name for '" + $DNSMode + "' DNS mode."
        }
        Set-IpamDNSMode `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -IpamFQName $IpamFQName `
            -DNSMode $DNSMode `
            -VirtualServerName $VirtualServerName
    }

    [String] AddDNSServer([String] $DNSServerName) {
        return Add-ContrailDNSServer -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -DNSServerName $DNSServerName
    }

    RemoveDNSServer([String] $DNSServerName) {
        $DNSServerUUID = FQNameToUuid -ContrailUrl $this.ContrailUrl `
                            -AuthToken $this.AuthToken `
                            -Type "virtual-DNS" `
                            -FQName @("default-domain", $DNSServerName)

        Remove-ContrailDNSServer -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -DNSServerUuid $DNSServerUUID `
            -Force
    }

    [String] AddDNSServerRecord([String] $DNSServerName,
                       [String] $HostName,
                       [String] $HostIP) {
        return Add-ContrailDNSRecordByStrings -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -DNSServerName $DNSServerName `
            -HostName $HostName `
            -HostIP $HostIP
    }
}
