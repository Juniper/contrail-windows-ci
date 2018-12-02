class SecurityGroupRepo : BaseRepo {
    [String] $ResourceName = 'security-group'

    SecurityGroupRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([SecurityGroup] $SecurityGroup) {
        $SecurityGroupAllowAllEntries = @{
            policy_rule = @()
        }

        foreach ($PolicyRule in $SecurityGroup.PolicyRules) {
            $SecurityGroupAllowAllEntries.policy_rule += $PolicyRule.GetRequest()
        }

        $Request = @{
            "security-group" = @{
                fq_name                = $SecurityGroup.GetFQName()
                parent_type            = 'project'
                security_group_entries = $SecurityGroupAllowAllEntries
            }
        }

        return $Request
    }
}
