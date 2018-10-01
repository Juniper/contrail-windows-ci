function Disable-VRouterExtension {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    Write-Log "Disabling Extension"

    $AdapterName = $SystemConfig.AdapterName
    $ForwardingExtensionName = $SystemConfig.ForwardingExtensionName
    $VMSwitchName = $SystemConfig.VMSwitchName()

    Invoke-Command -Session $Session -ScriptBlock {
        Disable-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue | Out-Null
        Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $Using:AdapterName | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $Using:AdapterName | Remove-ContainerNetwork -Force
    }
}

function Disable-AgentService {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Stopping Agent"
    Invoke-Command -Session $Session -ScriptBlock {
        Stop-Service ContrailAgent -ErrorAction SilentlyContinue | Out-Null
    }
}

function Stop-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Log "Stopping Docker Driver"

    Stop-ProcessIfExists -Session $Session -ProcessName "contrail-windows-docker"

    Invoke-Command -Session $Session -ScriptBlock {
        Stop-Service docker | Out-Null

        # Removing NAT objects when 'winnat' service is stopped may fail.
        # In this case, we have to try removing all objects but ignore failures for some of them.
        Get-NetNat | ForEach-Object {
            Remove-NetNat $_.Name -Confirm:$false -ErrorAction SilentlyContinue
        }

        # Removing ContainerNetworks may fail for NAT network when 'winnat'
        # service is disabled, so we have to filter out all NAT networks.
        Get-ContainerNetwork | Where-Object Name -NE nat | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        Get-ContainerNetwork | Where-Object Name -NE nat | Remove-ContainerNetwork -Force

        Start-Service docker | Out-Null
    }
}
