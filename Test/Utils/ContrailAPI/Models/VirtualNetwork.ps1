# Those are just informative to show dependencies
#include "Subnet.ps1"
#include "NetworkPolicy.ps1"
#include "Tag.ps1"

class VirtualNetwork : BaseResourceModel {
    [Subnet] $Subnet
    [FqName] $IpamFqName = [FqName]::new(@("default-domain", "default-project", "default-network-ipam"))
    [FqName[]] $NetworkPolicysFqNames = @()
    [FqName] $TagFqName
    [String] $ResourceName = 'virtual-network'
    [String] $ParentType = 'project'

    hidden [void] init([String] $Name, [String] $ProjectName, [Subnet] $Subnet, [FqName] $TagFqName) {
        $this.Name = $Name
        $this.ParentFqName = [FqName]::new(@('default-domain', $ProjectName))
        $this.Subnet = $Subnet
        $this.TagFqName = $TagFqName

        $this.Dependencies += [Dependency]::new('instance-ip', 'instance_ip_back_refs')
        $this.Dependencies += [Dependency]::new('virtual-machine-interface', 'virtual_machine_interface_back_refs')
    }

    VirtualNetwork([String] $Name, [String] $ProjectName, [Subnet] $Subnet) {
        $this.init($Name, $ProjectName, $Subnet, $null)
    }

    VirtualNetwork([String] $Name, [String] $ProjectName, [Subnet] $Subnet, [FqName] $TagFqName) {
        $this.init($Name, $ProjectName, $Subnet, $TagFqName)
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

        if ($null -ne $this.TagFqName) {
            $TagRef = @{
                to = $this.TagFqName.ToStringArray()
            }
            $Request.'virtual-network'.Add('tag_refs', @($TagRef))
        }

        $Policys = $this.GetPolicysReferences()
        $Request.'virtual-network'.Add('network_policy_refs', $Policys)

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
