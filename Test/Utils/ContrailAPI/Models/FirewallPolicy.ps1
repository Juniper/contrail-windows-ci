# Those are just informative to show dependencies
#include "FirewallRuleReference.ps1"

class FirewallPolicy : BaseResourceModel {
    [FirewallRuleReference[]] $FirewallRulesReferences = @()

    [String] $ResourceName = 'firewall-policy'
    [String] $ParentType = 'policy-management'

    FirewallPolicy([String] $Name) {
        $this.Name = $Name
        $this.ParentFqName = [FqName]::New(@('default-policy-management'))
    }

    [FirewallPolicy] AddFirewallRule([FqName] $FirewallRule, [int] $Sequence) {
        $this.FirewallRulesReferences += \
            @([FirewallRuleReference]::new($FirewallRule, $Sequence))
        return $this
    }

    [Hashtable] GetRequest() {
        $Request = @{
            $this.ResourceName = @{
                firewall_rule_refs = $this.GetFirewallRulesReferences()
            }
        }

        return $Request
    }

    hidden [Hashtable[]] GetFirewallRulesReferences() {
        $References = @()
        foreach ($RuleRef in $this.FirewallRulesReferences) {
            $References += @($RuleRef.GetRequest())
        }

        return $References
    }
}
