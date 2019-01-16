class FirewallDirection {
    [String] $Direction

    [String] Get() {
        return $this.Direction
    }
}

class UniLeftFirewallDirection : FirewallDirection {
    UniLeftFirewallDirection() {
        $this.Direction = '<'
    }
}

class UniRightFirewallDirection : FirewallDirection {
    UniRightFirewallDirection() {
        $this.Direction = '>'
    }
}

class BiFirewallDirection : FirewallDirection {
    BiFirewallDirection() {
        $this.Direction = '<>'
    }
}
