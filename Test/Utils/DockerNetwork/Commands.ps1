. $PSScriptRoot\..\..\TestConfigurationUtils.ps1

function Initialize-DockerNetworks {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $TenantName,
        # Not refactored tests passes here different type
        # than already refactored. Fortunately in scope of
        # usage in this function, they share interfaces.
        # TODO: Change PSobject to VirtualNetwork after
        #       tests refactor is finished.
        [Parameter(Mandatory=$true)] [PSobject[]] $Networks
    )
    foreach ($Network in $Networks) {
        $ID = New-DockerNetwork -Session $Session `
            -TenantName $TenantName `
            -Name $Network.Name `
            -Subnet "$( $Network.Subnet.IpPrefix )/$( $Network.Subnet.IpPrefixLen )"

        Write-Log "Created network id: $ID"
    }
}
