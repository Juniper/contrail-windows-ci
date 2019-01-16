class PortRange {
    [Int] $StartPort
    [Int] $EndPort

    [Hashtable] GetRequest() {
        return @{
            start_port = $this.StartPort
            end_port   = $this.EndPort
        }
    }

    static [PortRange] new_Range([Int] $StartPort, [Int] $EndPort) {
        $range = [PortRange]::new()
        $range.StartPort = $StartPort
        $range.EndPort = $EndPort
        return $range
    }

    static [PortRange] new_Full() {
        $range = [PortRange]::new()
        $range.StartPort = 0
        $range.EndPort = 65535
        return $range
    }
}
