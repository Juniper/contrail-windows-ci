class FloatingIpRepo : BaseRepo {
    [String] $ResourceName = 'floating-ip'

    FloatingIpRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([FloatingIp] $FloatingIp) {
        return @{
            'floating-ip' = @{
                fq_name = $FloatingIp.GetFQName()
                parent_type = 'floating-ip-pool'
                floating_ip_address = $FloatingIp.Address
            }
        }
    }
}
