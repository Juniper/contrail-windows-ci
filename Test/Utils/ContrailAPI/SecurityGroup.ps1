function Get-ContrailSecurityGroup {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Name)

    $ExpectedFqName = @("default-domain", $TenantName, $Name)

    return $API.FQNameToUuid('security-group', $ExpectedFqName)
}

function New-ContrailSecurityGroup {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Name)

        $SecurityGroupAllowAllEntries = @{
        policy_rule = @(
            @{
                direction = ">"
                protocol = "any"
                src_addresses = @(@{security_group = "local"})
                src_ports = @(@{start_port = 0; end_port = 65535})
                dst_addresses = @(@{subnet = @{ip_prefix = "0.0.0.0";ip_prefix_len = 0}})
                dst_ports = @(@{start_port = 0; end_port = 65535})
                ethertype = "IPv4"
            },
            @{
                direction = ">"
                protocol = "any"
                src_addresses = @(@{subnet = @{ip_prefix = "0.0.0.0";ip_prefix_len = 0}})
                src_ports = @(@{start_port = 0; end_port = 65535})
                dst_addresses = @(@{security_group = "local"})
                dst_ports = @(@{start_port = 0; end_port = 65535})
                ethertype = "IPv4"
            }
        )
    }

    $RequestSecurityGroup = @{
        "security-group" = @{
            fq_name = @("default-domain", $TenantName, $Name)
            parent_type = 'project'
            security_group_entries = $SecurityGroupAllowAllEntries
        }
    }

    $Response = $API.Post('security-group', $null, $RequestSecurityGroup)

    return $Response.'security-group'.'uuid'
}

function Add-OrReplaceContrailSecurityGroup {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Name)

    try {
        return New-ContrailSecurityGroup `
            -API $API `
            -TenantName $TenantName `
            -Name $Name
    } catch {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
            throw
        }

        $SecurityGroupUuid = Get-ContrailSecurityGroup `
            -API $API `
            -TenantName $TenantName `
            -Name $Name

        return $SecurityGroupUuid
    }
}
