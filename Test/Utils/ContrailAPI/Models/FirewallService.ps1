# Those are just informative to show dependencies
#include "Protocol.ps1"
#include "PortRange.ps1"

class FirewallService {
    [Protocol] $Protocol
    [PortRange] $SrcPorts
    [PortRange] $DstPorts

    FirewallService([Protocol] $Protocol, [PortRange] $SrcPorts, [PortRange] $DstPorts) {
        $this.Protocol = $Protocol
        $this.SrcPorts = $SrcPorts
        $this.DstPorts = $DstPorts
    }

    [Hashtable] GetRequest() {
        $Request = @{
            protocol  = ($this.Protocol -as [String])
            src_ports = $this.SrcPorts.GetRequest()
            dst_ports = $this.DstPorts.GetRequest()
        }

        return $Request
    }
}
