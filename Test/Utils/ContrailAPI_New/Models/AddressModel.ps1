class Address {
    [PSobject] GetRequest() {
        throw "Address.GetRequest() is a pure virtual method"
    }
}

class SubnetAddress : Address {
    [String] $IpPrefix
    [Int] $IpPrefixLength

    [PSobject] GetRequest() {
        return @{
            subnet = @{
                ip_prefix     = $this.IpPrefix
                ip_prefix_len = $this.IpPrefixLength
            }
        }
    }

    static [SubnetAddress] new_Full() {
        $address = [SubnetAddress]::new()
        $address.IpPrefix = "0.0.0.0"
        $address.IpPrefixLength = 0
        return $address
    }
}

class SecurityGroupAddress : Address {
    [String] $SecurityGroup = 'local'

    [PSobject] GetRequest() {
        return @{
            security_group = $this.SecurityGroup
        }
    }
}

class VirtualNetworkAddress : Address {
    [String] $VirtualNetwork = 'any'

    [PSobject] GetRequest() {
        return @{
            virtual_network = $this.VirtualNetwork
        }
    }
}
