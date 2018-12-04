# Those are just informative to show dependencies
#include "SubnetModel.ps1"
#include "NetworkPolicyModel.ps1"

class VirtualNetwork : BaseRepoModel {
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
    }

    [String[]] GetFQName() {
        return @($this.DomainName, $this.ProjectName, $this.Name)
    }
}
