# Those are just informative to show dependencies
#include "AddressModel.ps1"
#include "PortRangeModel.ps1"

Enum Protocol {
    any
}

Enum EtherType {
    IPv4
}

class PolicyRule {
    [String] $Direction = ">"
    [Protocol] $Protocol = [Protocol]::any
    [EtherType] $EtherType = [EtherType]::IPv4
    [Address] $SourceAddress
    [PortRange] $SourcePorts
    [Address] $DestinationAddress
    [PortRange] $DestinationPorts

    [PSobject] GetRequest() {
        return @{
            direction     = $this.Direction
            protocol      = ($this.Protocol -as [String])
            src_addresses = @($this.SourceAddress.GetRequest())
            src_ports     = @($this.SourcePorts.GetRequest())
            dst_addresses = @($this.DestinationAddress.GetRequest())
            dst_ports     = @($this.DestinationPorts.GetRequest())
            ethertype     = ($this.EtherType -as [String])
        }
    }
}
