# Those are just informative to show dependencies
#include "SubnetModel.ps1"
#include "NetworkPolicyModel.ps1"

class VirtualNetwork : BaseResourceModel {
    [string] $Name
    [string] $ProjectName
    [string] $DomainName = 'default-domain'
    [Subnet] $Subnet
    [string[]] $IpamFqName = @("default-domain", "default-project", "default-network-ipam")
    [NetworkPolicy[]] $NetworkPolicys = @()

    VirtualNetwork([string] $Name, [string] $ProjectName, [Subnet] $Subnet) {
        $this.Name = $Name
        $this.ProjectName = $ProjectName
        $this.Subnet = $Subnet

        $this.Dependencies += [Dependency]::new('instance-ip', 'instance_ip_back_refs')
        $this.Dependencies += [Dependency]::new('virtual-machine-interface', 'virtual_machine_interface_back_refs')
    }

    [String[]] GetFQName() {
        return @($this.DomainName, $this.ProjectName, $this.Name)
    }

    [String] $ResourceName = 'virtual-network'
    [String] $ParentType = 'project'

    [PSobject] GetRequest() {

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

    hidden [PSobject[]] GetPolicysReferences() {
        $References = @()
        if ($this.NetworkPolicys) {
            foreach ($NetworkPolicy in $this.NetworkPolicys) {
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
}
