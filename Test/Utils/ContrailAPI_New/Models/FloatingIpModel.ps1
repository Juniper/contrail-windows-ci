class FloatingIp : BaseResourceModel {
    [string] $Name
    [string[]] $PoolFqName
    [string] $Address
    [string[][]] $PortFqNames

    FloatingIp([string] $Name, [string[]] $PoolFqName, [string] $Address) {
        $this.Name = $Name
        $this.PoolFqName = $PoolFqName
        $this.Address = $Address
    }

    [String[]] GetFQName() {
        return ($this.PoolFqName + @($this.Name))
    }

    [String] $ResourceName = 'floating-ip'
    [String] $ParentType = 'floating-ip-pool'

    [PSobject] GetRequest() {
        $Request = @{
            'floating-ip' = @{
                floating_ip_address = $this.Address
            }
        }
        $Ports = $this.GetPortsReferences()
        if($Ports) {
            $Request.'floating-ip'.Add('virtual_machine_interface_refs', $Ports)
        }

        return $Request
    }

    hidden [PSobject[]] GetPortsReferences() {
        $References = @()
        if($this.PortFqNames) {
            foreach ($PortFqName in $this.PortFqNames) {
                $Ref = @{
                    "to" = $PortFqName
                }
                $References += $Ref
            }
        }
        return $References
    }
}
