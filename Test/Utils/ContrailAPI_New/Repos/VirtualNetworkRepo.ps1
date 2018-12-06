class VirtualNetworkRepo : ContrailRepo {
    VirtualNetworkRepo([ContrailRestApi] $API) : base($API) {}

    [String[][]] GetPorts([VirtualNetwork] $VirtualNetwork) {
        $Uuid = $this.API.FqNameToUuid($VirtualNetwork.ResourceName, $VirtualNetwork.GetFqName())
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
