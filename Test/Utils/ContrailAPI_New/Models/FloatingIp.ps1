class FloatingIp : BaseResourceModel {
    [String] $Name
    [String[]] $PoolFqName
    [String] $Address
    [String[][]] $PortFqNames

    [String] $ResourceName = 'floating-ip'
    [String] $ParentType = 'floating-ip-pool'

    FloatingIp([String] $Name, [String[]] $PoolFqName, [String] $Address) {
        $this.Name = $Name
        $this.PoolFqName = $PoolFqName
        $this.Address = $Address
    }

    [String[]] GetFqName() {
        return ($this.PoolFqName + @($this.Name))
    }

    [Hashtable] GetRequest() {
        $Request = @{
            'floating-ip' = @{
                floating_ip_address = $this.Address
            }
        }
        $Ports = $this.GetPortsReferences()
        if ($Ports) {
            $Request.'floating-ip'.Add('virtual_machine_interface_refs', $Ports)
        }

        return $Request
    }

    hidden [Hashtable[]] GetPortsReferences() {
        $References = @()
        if ($this.PortFqNames) {
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
