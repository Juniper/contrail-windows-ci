# Those are just informative to show dependencies
#include "AddressModel.ps1"
#include "PortRangeModel.ps1"

Enum Protocol {
    any
}

Enum EtherType {
    IPv4
}

class RuleSequence {
    [Int] $Major
    [Int] $Minor

    RuleSequence([Int] $Major, [Int] $Minor) {
        $this.Major = $Major
        $this.Minor = $Minor
    }

    [PSobject] GetRequest() {
        return @{
            major = $this.Major
            minor = $this.Minor
        }
    }
}

class RuleAction {}

class SimplePassRuleAction : RuleAction {
    [PSobject] GetRequest() {
        return @{ "simple_action" = "pass" }
    }
}

class PolicyRule {
    [String] $Direction = ">"
    [Protocol] $Protocol = [Protocol]::any
    [EtherType] $EtherType = [EtherType]::IPv4
    [Address] $SourceAddress
    [PortRange] $SourcePorts
    [Address] $DestinationAddress
    [PortRange] $DestinationPorts

    [RuleSequence] $Sequence
    [RuleAction] $Action

    [PSobject] GetRequest() {
        $Request = @{
            direction     = $this.Direction
            protocol      = ($this.Protocol -as [String])
            src_addresses = @($this.SourceAddress.GetRequest())
            src_ports     = @($this.SourcePorts.GetRequest())
            dst_addresses = @($this.DestinationAddress.GetRequest())
            dst_ports     = @($this.DestinationPorts.GetRequest())
            ethertype     = ($this.EtherType -as [String])
        }

        if ($this.Action) {
            $Request.Add('action_list', $this.Action.GetRequest())
        }
        if ($this.Sequence) {
            $Request.Add('rule_sequence', $this.Sequence.GetRequest())
        }

        return $Request
    }
}
