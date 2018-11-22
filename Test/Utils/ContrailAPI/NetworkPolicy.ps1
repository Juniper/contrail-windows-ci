. $PSScriptRoot\Constants.ps1

function New-ContrailPassAllPolicyDefinition {
    Param ([Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Name)

    $Rule = @{
        "action_list" = @{ "simple_action" = "pass" }
        "direction" = "<>"
        "dst_addresses" = @(
            @{
                "network_policy" = $null
                "security_group" = $null
                "subnet" = $null
                "virtual_network" = "any"
            }
        )
        "dst_ports" = @(
            @{
                "end_port" = -1
                "start_port" = -1
            }
        )
        "ethertype" = "IPv4"
        "protocol" = "any"
        "rule_sequence" = @{
            "major" = -1
            "minor" = -1
        }
        "rule_uuid" = $null
        "src_addresses" = @(
            @{
                "network_policy" = $null
                "security_group" = $null
                "subnet" = $null
                "virtual_network" = "any"
            }
        )
        "src_ports" = @(
            @{
                "end_port" = -1
                "start_port" = -1
            }
        )
    }

    $BodyObject = @{
        "network-policy" = @{
            "fq_name" = @("default-domain", $TenantName, $Name)
            "name" = $Name
            "display_name" = $Name
            "network_policy_entries" = @{
                "policy_rule" = @( $Rule )
            }
        }
    }

    return $BodyObject
}

function Add-ContrailPassAllPolicy {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Name)

    $BodyObject = New-ContrailPassAllPolicyDefinition $TenantName $Name
    $Response = $API.Post('network-policy', $null, $BodyObject)
    return $Response.'network-policy'.'uuid'
}

function Remove-ContrailPolicy {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Uuid)

    $API.Delete('network-policy', $Uuid, $null)
}
