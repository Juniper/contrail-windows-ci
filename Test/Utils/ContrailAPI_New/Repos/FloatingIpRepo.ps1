class FloatingIpRepo : BaseRepo {
    [String] $ResourceName = 'floating-ip'

    FloatingIpRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([FloatingIp] $FloatingIp) {
        $Request = @{
            'floating-ip' = @{
                fq_name = $FloatingIp.GetFQName()
                parent_type = 'floating-ip-pool'
                floating_ip_address = $FloatingIp.Address
            }
        }
        $Ports = $this.GetPortsReferences($FloatingIp)
        if($Ports) {
            $Request.'floating-ip'.Add('virtual_machine_interface_refs', $Ports)
        }

        return $Request
    }

    hidden [PSobject[]] GetPortsReferences([FloatingIp] $FloatingIp) {
        $References = @()
        if($FloatingIp.PortFqNames) {
            foreach ($PortFqName in $FloatingIp.PortFqNames) {
                $Ref = @{
                    "to" = $PortFqName
                }
                $References += $Ref
            }
        }
        return $References
    }

    [Void] SetPorts([FloatingIp] $FloatingIp) {
        $Ports = $this.GetPortsReferences($FloatingIp)
        $Request = @{
            "floating-ip" = @{
                "floating_ip_address" = $FloatingIp.Address
                "virtual_machine_interface_refs" = $Ports
            }
        }
        $Uuid = $this.API.FQNameToUuid($this.ResourceName, $FloatingIp.GetFQName())
        $this.API.Put($this.ResourceName, $Uuid, $Request) | Out-Null
    }
}
