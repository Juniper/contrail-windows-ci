# Those are just informative to show dependencies
#include "PolicyRuleModel.ps1"

class NetworkPolicy : BaseResourceModel {
    [string] $Name
    [string] $ProjectName
    [string] $DomainName = 'default-domain'
    [PolicyRule[]] $PolicyRules = @()

    NetworkPolicy([String] $Name, [String] $ProjectName) {
        $this.Name = $Name
        $this.ProjectName = $ProjectName
    }

    [String[]] GetFQName() {
        return @($this.DomainName, $this.ProjectName, $this.Name)
    }

    static [NetworkPolicy] new_PassAll([String] $Name, [String] $ProjectName) {
        $policy = [NetworkPolicy]::new($Name, $ProjectName)
        $rule = [PolicyRule]::new()
        $rule.Direction = "<>"
        $rule.SourceAddress = [VirtualNetworkAddress]::new()
        $rule.SourcePorts = [PortRange]::new_Full()
        $rule.DestinationAddress = [VirtualNetworkAddress]::new()
        $rule.DestinationPorts = [PortRange]::new_Full()
        $rule.Sequence = [RuleSequence]::new(-1, -1)
        $rule.Action = [SimplePassRuleAction]::new()
        $policy.PolicyRules += $rule
        return $policy
    }

    [String] $ResourceName = 'network-policy'
    [String] $ParentType = 'project'

    [PSobject] GetRequest() {
        $NetworkPolicyEntries = @{
            policy_rule = @()
        }

        foreach ($PolicyRule in $this.PolicyRules) {
            $NetworkPolicyEntries.policy_rule += $PolicyRule.GetRequest()
        }

        $Request = @{
            "network-policy" = @{
                name                   = $this.Name
                display_name           = $this.Name
                network_policy_entries = $NetworkPolicyEntries
            }
        }

        return $Request
    }
}
