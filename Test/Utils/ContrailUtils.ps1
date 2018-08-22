. $PSScriptRoot\ContrailAPI\Constants.ps1

function Get-AccessTokenFromKeystone {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingUserNameAndPassWordParams",
        "", Justification="We don't care that it's plaintext, it's just test env.")]
    Param ([Parameter(Mandatory = $true)] [string] $AuthUrl,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Username,
           [Parameter(Mandatory = $true)] [string] $Password)

    $Request = @{
        auth = @{
            tenantName          = $TenantName
            passwordCredentials = @{
                username = $Username
                password = $Password
            }
        }
    }

    $AuthUrl += "/tokens"
    $Response = Invoke-RestMethod -Uri $AuthUrl -Method Post -ContentType "application/json" `
        -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)
    return $Response.access.token.id
}

function Add-ContrailProject {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $ProjectName)

    $Request = @{
        "project" = @{
            fq_name = @("default-domain", $ProjectName)
        }
    }

    $RequestUrl = $ContrailUrl + "/projects"
    $Response = Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post -ContentType "application/json" -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)

    return $Response.'project'.'uuid'
}

function Add-ContrailVirtualRouter {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $RouterName,
           [Parameter(Mandatory = $true)] [string] $RouterIp)

    $Request = @{
        "virtual-router" = @{
            parent_type               = "global-system-config"
            fq_name                   = @("default-global-system-config", $RouterName)
            virtual_router_ip_address = $RouterIp
        }
    }

    $RequestUrl = $ContrailUrl + "/virtual-routers"
    $Response = Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post -ContentType "application/json" -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)

    return $Response.'virtual-router'.'uuid'
}

function Remove-ContrailVirtualRouter {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $RouterUuid)

    $RequestUrl = $ContrailUrl + "/virtual-router/" + $RouterUuid
    Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete | Out-Null
}

function Add-ContrailFloatingIpPool {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $NetworkName,
           [Parameter(Mandatory = $true)] [string] $PoolName)

    $Request = @{
        "floating-ip-pool" = @{
            "fq_name" = @("default-domain", $TenantName, $NetworkName, $PoolName)
            "parent_type" = "virtual-network"
            "uuid" = $null
        }
    }

    $RequestUrl = $ContrailUrl + "/floating-ip-pools"
    $Response = Invoke-RestMethod `
        -Uri $RequestUrl `
        -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post `
        -ContentType "application/json" `
        -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)

    return $Response.'floating-ip-pool'.'uuid'
}

function Remove-ContrailFloatingIpPool {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $PoolUuid)

    $RequestUrl = $ContrailUrl + "/floating-ip-pool/" + $PoolUuid
    Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete | Out-Null
}

function Add-ContrailFloatingIp {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $PoolUuid,
           [Parameter(Mandatory = $true)] [string] $IPName,
           [Parameter(Mandatory = $true)] [string] $IPAddress)

    $PoolUrl = $ContrailUrl + "/floating-ip-pool/" + $PoolUuid
    $Pool = Invoke-RestMethod -Uri $PoolUrl -Headers @{"X-Auth-Token" = $AuthToken}

    $PoolFqName = $Pool."floating-ip-pool".fq_name
    $FipFqName = $PoolFqName + $IPName

    $Request = @{
        "floating-ip" = @{
            "floating_ip_address" = $IPAddress
            "fq_name" = $FipFqName
            "parent_type" = "floating-ip-pool"
            "uuid" = $null
        }
    }
    $RequestUrl = $ContrailUrl + "/floating-ips"
    $Response = Invoke-RestMethod `
        -Uri $RequestUrl `
        -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post `
        -ContentType "application/json" `
        -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $Request)
    return $Response.'floating-ip'.'uuid'
}

function Set-ContrailFloatingIpPorts {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $IpUuid,
           [Parameter(Mandatory = $true)] [string[]] $PortFqNames,
           [Parameter(Mandatory = $false)] [string] $TenantName)

    $FipUrl = $ContrailUrl + "/floating-ip/" + $IpUuid
    $Fip = Invoke-RestMethod -Uri $FipUrl -Headers @{"X-Auth-Token" = $AuthToken}

    $InterfaceRefs = @()
    foreach ($PortFqName in $PortFqNames) {
        $Ref = @{
            "to" = $PortFqName -Split ":"
        }
        $InterfaceRefs = $InterfaceRefs + $Ref
    }

    $RequestBody = @{
        "floating-ip" = @{
            "floating_ip_address" = $Fip.'floating-ip'.floating_ip_address
            "fq_name" = $Fip.'floating-ip'.fq_name
            "parent_type" = $Fip.'floating-ip'.parent_type
            "uuid" = $Fip.'floating-ip'.uuid
            "virtual_machine_interface_refs" = $InterfaceRefs
        }
    }
    Invoke-RestMethod `
        -Uri $FipUrl `
        -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Put `
        -ContentType "application/json" `
        -Body (ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $RequestBody)
}

function Remove-ContrailFloatingIp {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $IpUuid)

    $RequestUrl = $ContrailUrl + "/floating-ip/" + $IpUuid
    Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete | Out-Null
}

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
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $Name)

    $Url = $ContrailUrl + "/network-policys"
    $BodyObject = New-ContrailPassAllPolicyDefinition $TenantName $Name
    # We need to escape '<>' in 'direction' field because reasons
    # http://www.azurefieldnotes.com/2017/05/02/replacefix-unicode-characters-created-by-convertto-json-in-powershell-for-arm-templates/
    $Body = ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $BodyObject | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
    $Response = Invoke-RestMethod `
        -Uri $Url `
        -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post `
        -ContentType "application/json" `
        -Body $Body
    return $Response.'network-policy'.'uuid'
}

function Remove-ContrailPolicy {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $Uuid)

    $Url = $ContrailUrl + "/network-policy/" + $Uuid
    Invoke-RestMethod -Uri $Url -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete
}

function Add-ContrailPolicyToNetwork {
    Param ([Parameter(Mandatory = $true)] [string] $ContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $PolicyUuid,
           [Parameter(Mandatory = $true)] [string] $NetworkUuid)
    $NetworkUrl = $ContrailUrl + "/virtual-network/" + $NetworkUuid
    $Network = Invoke-RestMethod -Uri $NetworkUrl -Headers @{"X-Auth-Token" = $AuthToken}

    $PolicyRef = @{
        "uuid" = $PolicyUuid
        "attr" = @{
            "timer" = $null
            "sequence" = @{
                "major" = 0
                "minor" = 0
            }
        }
    }
    $BodyObject = @{
        "virtual-network" = @{
            "uuid" = $NetworkUuid
            "network_policy_refs" = @( $PolicyRef )
        }
    }
    $Body = ConvertTo-Json -Depth $CONVERT_TO_JSON_MAX_DEPTH $BodyObject
    Invoke-RestMethod `
        -Uri $NetworkUrl `
        -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Put `
        -ContentType "application/json" `
        -Body $Body
}
