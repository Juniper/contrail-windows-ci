Describe "Tunnelling with Agent tests" {
    Context "ICMP" {
        It "works over MPLSoGRE" -Pending {
            # Test-ICMPoMPLSoGRE
        }

        It "works over MPLSoUDP" -Pending {
            # Test-ICMPoMPLSoUDP
        }
    }

    Context "TCP" {
        It "works over MPLSoGRE" -Pending {
            # Test-MultihostTcpTraffic
            # TODO: Is this actually correct test for MPLSoGRE?
        }
    }

    Context "UDP" {
        It "works over MPLsoGRE" -Pending {
            # Test-MultihostUdpTraffic
            # TODO: Is this actually correct test for MPLSoGRE?
        }
    }
}
