class NetworkPolicyRepo : BaseRepo {
    [String] $ResourceName = 'network-policy'

    NetworkPolicyRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([NetworkPolicy] $NetworkPolicy) {
        $NetworkPolicyEntries = @{
            policy_rule = @()
        }

        foreach ($PolicyRule in $NetworkPolicy.PolicyRules) {
            $NetworkPolicyEntries.policy_rule += $PolicyRule.GetRequest()
        }

        $Request = @{
            "network-policy" = @{
                fq_name                = $NetworkPolicy.GetFQName()
                name                   = $NetworkPolicy.Name
                display_name           = $NetworkPolicy.Name
                network_policy_entries = $NetworkPolicyEntries
            }
        }

        return $Request
    }
}
