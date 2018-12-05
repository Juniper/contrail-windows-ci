class VirtualNetworkRepo : ContrailRepo {
    VirtualNetworkRepo([ContrailNetworkManager] $API) : base($API) {}

    [string[][]] GetPorts([VirtualNetwork] $VirtualNetwork) {
        $Uuid = $this.API.FQNameToUuid($VirtualNetwork.ResourceName, $VirtualNetwork.GetFQName())
        $VirtualNetworkResponse = $this.API.Get('virtual-network', $Uuid, $null)
        $Interfaces = $VirtualNetworkResponse.'virtual-network'.'virtual_machine_interface_back_refs'

        $Result = @()
        foreach ($Interface in $Interfaces) {
            $FqName = $Interface.to
            $Result += , $FqName
        }

        return $Result
    }
}
