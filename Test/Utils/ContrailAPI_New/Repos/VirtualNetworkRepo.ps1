class VirtualNetworkRepo : BaseRepo {
    [String] $ResourceName = 'virtual-network'

    VirtualNetworkRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([VirtualNetwork] $VirtualNetwork) {

        $IpamSubnet = @{
            subnet           = @{
                ip_prefix     = $VirtualNetwork.Subnet.IpPrefix
                ip_prefix_len = $VirtualNetwork.Subnet.IpPrefixLen
            }
            addr_from_start  = $true
            enable_dhcp      = $VirtualNetwork.Subnet.DHCP
            default_gateway  = $VirtualNetwork.Subnet.DefaultGateway
            allocation_pools = @(@{
                    start = $VirtualNetwork.Subnet.AllocationPoolsStart
                    end   = $VirtualNetwork.Subnet.AllocationPoolsEnd
                })
        }

        $NetworkImap = @{
            attr = @{
                ipam_subnets = @($IpamSubnet)
            }
            to   = $VirtualNetwork.IpamFqName
        }

        $Request = @{
            'virtual-network' = @{
                parent_type       = 'project'
                fq_name           = $VirtualNetwork.GetFQName()
                network_ipam_refs = @($NetworkImap)
            }
        }

        $Policys = $this.GetPolicysReferences($VirtualNetwork)
        if ($Policys) {
            $Request.'virtual-network'.Add('network_policy_refs', $Policys)
        }

        return $Request
    }

    [void] RemoveDependencies([VirtualNetwork] $VirtualNetwork) {
        $Uuid = $this.API.FQNameToUuid($this.ResourceName, $VirtualNetwork.GetFQName())
        $VirtualNetworkResponse = $this.API.Get($this.ResourceName, $Uuid, $null)
        $Props = $VirtualNetworkResponse.'virtual-network'.PSobject.Properties.Name

        if ($Props -contains 'instance_ip_back_refs') {
            ForEach ($IpInstance in $VirtualNetworkResponse.'virtual-network'.'instance_ip_back_refs') {
                $this.API.Delete('instance-ip', $IpInstance.'uuid', $null)
            }
        }

        if ($Props -contains 'virtual_machine_interface_back_refs') {
            ForEach ($VirtualMachine in $VirtualNetworkResponse.'virtual-network'.'virtual_machine_interface_back_refs') {
                $this.API.Delete('virtual-machine-interface', $VirtualMachine.'uuid', $null)
            }
        }
    }

    [string[][]] GetPorts([VirtualNetwork] $VirtualNetwork) {
        $Uuid = $this.API.FQNameToUuid($this.ResourceName, $VirtualNetwork.GetFQName())
        $VirtualNetworkResponse = $this.API.Get('virtual-network', $Uuid, $null)
        $Interfaces = $VirtualNetworkResponse.'virtual-network'.'virtual_machine_interface_back_refs'

        $Result = @()
        foreach ($Interface in $Interfaces) {
            $FqName = $Interface.to
            $Result += , $FqName
        }

        return $Result
    }

    hidden [PSobject[]] GetPolicysReferences([VirtualNetwork] $VirtualNetwork) {
        $References = @()
        if ($VirtualNetwork.NetworkPolicys) {
            foreach ($NetworkPolicy in $VirtualNetwork.NetworkPolicys) {
                $Ref = @{
                    "to"   = $NetworkPolicy.GetFQName()
                    "attr" = @{
                        "timer"    = $null
                        "sequence" = @{
                            "major" = 0
                            "minor" = 0
                        }
                    }
                }
                $References += $Ref
            }
        }
        return $References
    }

    [void] SetPolicy([VirtualNetwork] $VirtualNetwork) {
        $NetworkUuid = $this.API.FQNameToUuid($this.ResourceName, $VirtualNetwork.GetFQName())

        $Policys = $this.GetPolicysReferences($VirtualNetwork)

        $BodyObject = @{
            "virtual-network" = @{
                "network_policy_refs" = $Policys
            }
        }

        $this.API.Put($this.ResourceName, $NetworkUuid, $BodyObject) | Out-Null
    }
}
