class SubnetConfiguration {
    [string] $IpPrefix;
    [int] $IpPrefixLen;
    [string] $DefaultGateway;
    [string] $AllocationPoolsStart;
    [string] $AllocationPoolsEnd;

    SubnetConfiguration([string] $IpPrefix, [int] $IpPrefixLen,
        [string] $DefaultGateway, [string] $AllocationPoolsStart,
        [string] $AllocationPoolsEnd) {
        $this.IpPrefix = $IpPrefix
        $this.IpPrefixLen = $IpPrefixLen
        $this.DefaultGateway = $DefaultGateway;
        $this.AllocationPoolsStart = $AllocationPoolsStart;
        $this.AllocationPoolsEnd = $AllocationPoolsEnd;
    }
}

class Network {
    [string] $Name;
    [SubnetConfiguration] $Subnet;

    Network([string] $Name, [SubnetConfiguration] $Subnet) {
        $this.Name = $Name
        $this.Subnet = $Subnet
    }
}
