class VirtualRouterRepo : BaseRepo {
    [String] $ResourceName = 'virtual-router'

    VirtualRouterRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([VirtualRouter] $VirtualRouter) {
        return @{
            'virtual-router' = @{
                parent_type               = 'global-system-config'
                fq_name                   = $VirtualRouter.GetFQName()
                virtual_router_ip_address = $VirtualRouter.Ip
            }
        }
    }
}
