class SecurityGroupRepo : BaseRepo {
    [String] $ResourceName = 'security-group'

    SecurityGroupRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([SecurityGroup] $SecurityGroup) {
        $SecurityGroupEntries = @{
            policy_rule = @()
        }

        foreach ($PolicyRule in $SecurityGroup.PolicyRules) {
            $SecurityGroupEntries.policy_rule += $PolicyRule.GetRequest()
        }

        $Request = @{
            "security-group" = @{
                fq_name                = $SecurityGroup.GetFQName()
                parent_type            = 'project'
                security_group_entries = $SecurityGroupEntries
            }
        }

        return $Request
    }
}
