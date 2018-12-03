class FloatingIpPoolRepo : BaseRepo {
    [String] $ResourceName = 'floating-ip-pool'

    FloatingIpPoolRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([FloatingIpPool] $FloatingIpPool) {
        return @{
            'floating-ip-pool' = @{
                fq_name = $FloatingIpPool.GetFQName()
                parent_type = 'virtual-network'
            }
        }
    }
}
