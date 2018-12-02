# Those are just informative to show dependencies
#include "PolicyRuleModel.ps1"

class SecurityGroup : BaseRepoModel {
    [string] $Name
    [string] $ProjectName
    [string] $DomainName = 'default-domain'
    [PolicyRule[]] $PolicyRules = @()

    SecurityGroup([String] $Name, [String] $ProjectName) {
        $this.Name = $Name
        $this.ProjectName = $ProjectName
    }

    [String[]] GetFQName() {
        return @($this.DomainName, $this.ProjectName, $this.Name)
    }

    static [SecurityGroup] new_Default([String] $ProjectName) {
        $group = [SecurityGroup]::new('default', $ProjectName)
        $rule1 = [PolicyRule]::new()
        $rule1.SourceAddress = [SecurityGroupAddress]::new()
        $rule1.SourcePorts = [PortRange]::new_Full()
        $rule1.DestinationAddress = [SubnetAddress]::new_Full()
        $rule1.DestinationPorts = [PortRange]::new_Full()
        $rule2 = [PolicyRule]::new()
        $rule2.SourceAddress = [SubnetAddress]::new_Full()
        $rule2.SourcePorts = [PortRange]::new_Full()
        $rule2.DestinationAddress = [SecurityGroupAddress]::new()
        $rule2.DestinationPorts = [PortRange]::new_Full()
        $group.PolicyRules += @($rule1, $rule2)
        return $group
    }
}
