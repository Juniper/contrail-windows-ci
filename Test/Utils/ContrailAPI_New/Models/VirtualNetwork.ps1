# Those are just informative to show dependencies
#include "Subnet.ps1"
#include "NetworkPolicy.ps1"

class VirtualNetwork : BaseResourceModel {
    [String] $Name
    [String] $ProjectName
    [String] $DomainName = 'default-domain'
    [Subnet] $Subnet
    [String[]] $IpamFqName = @("default-domain", "default-project", "default-network-ipam")
    [String[][]] $NetworkPolicysFqNames = @()

    [String] $ResourceName = 'virtual-network'
    [String] $ParentType = 'project'

    VirtualNetwork([String] $Name, [String] $ProjectName, [Subnet] $Subnet) {
        $this.Name = $Name
        $this.ProjectName = $ProjectName
        $this.Subnet = $Subnet

        $this.Dependencies += [Dependency]::new('instance-ip', 'instance_ip_back_refs')
        $this.Dependencies += [Dependency]::new('virtual-machine-interface', 'virtual_machine_interface_back_refs')
    }

    [String[]] GetFqName() {
        return @($this.DomainName, $this.ProjectName, $this.Name)
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
            allocation_pools = @(@{
                    start = $this.Subnet.AllocationPoolsStart
                    end   = $this.Subnet.AllocationPoolsEnd
                })
        }

        $NetworkImap = @{
            attr = @{
                ipam_subnets = @($IpamSubnet)
            }
            to   = $this.IpamFqName
        }

        $Request = @{
            'virtual-network' = @{
                network_ipam_refs = @($NetworkImap)
            }
        }

        $Policys = $this.GetPolicysReferences()
        $Request.'virtual-network'.Add('network_policy_refs', $Policys)

        return $Request
    }

    hidden [Hashtable[]] GetPolicysReferences() {
        $References = @()
        if ($this.NetworkPolicys) {
            foreach ($NetworkPolicy in $this.NetworkPolicysFqNames) {
                $Ref = @{
                    "to"   = $NetworkPolicy
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
}
