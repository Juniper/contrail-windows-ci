# Those are just informative to show dependencies
#include "Subnet.ps1"
#include "NetworkPolicy.ps1"

class VirtualNetwork : BaseResourceModel {
    [Subnet] $Subnet
    [FqName] $IpamFqName = [FqName]::new(@("default-domain", "default-project", "default-network-ipam"))
    [FqName[]] $NetworkPolicysFqNames = @()
    [Boolean] $IpFabricForwarding = $false

    [String] $ResourceName = 'virtual-network'
    [String] $ParentType = 'project'

    VirtualNetwork([String] $Name, [String] $ProjectName, [Subnet] $Subnet) {
        $this.Name = $Name
        $this.ParentFqName = [FqName]::new(@('default-domain', $ProjectName))
        $this.Subnet = $Subnet

        $this.Dependencies += [Dependency]::new('instance-ip', 'instance_ip_back_refs')
        $this.Dependencies += [Dependency]::new('virtual-machine-interface', 'virtual_machine_interface_back_refs')
    }

    EnableIpFabricForwarding([FqName] $ProviderNetworkFqName, [String] $ProviderNetworkUuid, [String] $ProviderNetworkUrl) {
        $this.IpFabricForwarding = $true
        $this.ProviderNetworkFqName = $ProviderNetworkFqName
        $this.ProviderNetworkUuid = $ProviderNetworkUuid
        $this.ProviderNetworkUrl = $ProviderNetworkUrl
    }

    [Hashtable] GetRequest() {

        $IpamSubnet = @{
            subnet           = @{
                ip_prefix     = $this.Subnet.IpPrefix
                ip_prefix_len = $this.Subnet.IpPrefixLen
            }
            addr_from_start  = $true
            enable_dhcp      = $this.Subnet.DHCP
            default_gateway  = $this.Subnet.DefaultGateway
            allocation_pools = @(
                @{
                    start = $this.Subnet.AllocationPoolsStart
                    end   = $this.Subnet.AllocationPoolsEnd
                }
            )
        }

        $NetworkImap = @{
            attr = @{
                ipam_subnets = @($IpamSubnet)
            }
            to   = $this.IpamFqName.ToStringArray()
        }

        $Request = @{
            'virtual-network' = @{
                network_ipam_refs = @($NetworkImap)
            }
        }

        $Policys = $this.GetPolicysReferences()
        $Request.'virtual-network'.Add('network_policy_refs', $Policys)

        if ($true -eq $this.IpFabricForwarding) {
            $ProviderProperties = @{
                segmentation_id = 0
                physical_network = $this.ProviderNetworkFqName.ToString()
            }
            $Request.'virtual-network'.Add('provider_properties', $ProviderProperties)

            $VirtualNetworkRefs = @{
                href = $this.ProviderNetworkUrl
                uuid = $this.ProviderNetworkUuid
                to = $this.ProviderNetworkFqName
            }
            $Request.'virtual-network'.Add('virtual_network_refs', $VirtualNetworkRefs)
        }

        return $Request
    }

    hidden [Hashtable[]] GetPolicysReferences() {
        $References = @()
        foreach ($NetworkPolicy in $this.NetworkPolicysFqNames) {
            $Ref = @{
                "to"   = $NetworkPolicy.ToStringArray()
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

        return $References
    }
}
