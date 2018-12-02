class PortRange {
    [Int] $StartPort
    [Int] $EndPort

    [PSobject] GetRequest() {
        return @{
            start_port = $this.StartPort
            end_port   = $this.EndPort
        }
    }

    static [PortRange] new_Full() {
        $range = [PortRange]::new()
        $range.StartPort = 0
        $range.EndPort = 65535
        return $range
    }
}
