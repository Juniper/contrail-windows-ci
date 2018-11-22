. $PSScriptRoot\Constants.ps1

function Set-EncapPriorities {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string[]] $PrioritiesList)

    $GetResponse = $API.Get('global-vrouter-config', $null, $null)

    # Assume there's only one global-vrouter-config
    $Uuid = $GetResponse."global-vrouter-configs"[0].uuid

    # Request constructed based on
    # http://www.opencontrail.org/documentation/api/r4.0/contrail_openapi.html#globalvrouterconfigcreate
    $Request = @{
        "global-vrouter-config" = @{
            parent_type = "global-system-config"
            fq_name = @("default-global-system-config", "default-global-vrouter-config")
            encapsulation_priorities = @{
                encapsulation = $PrioritiesList
            }
        }
    }

    $API.Put('global-vrouter-config', $Uuid, $Request)
}
