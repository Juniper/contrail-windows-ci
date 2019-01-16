class FirewallDirection {
    [String] $Direction

    [String] Get() {
        return $this.Direction
    }
}

class BiFirewallDirection : FirewallDirection {
    BiFirewallDirection() {
        $this.Direction = '<>'
    }
}
