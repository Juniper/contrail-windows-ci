# [Shelly-Bug] Shelly doesn't handle imports of classes yet.
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testenv.ps1 # allow unused-imports

. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1

. $PSScriptRoot\..\DockerNetwork\DockerNetwork.ps1

function Initialize-ComputeNode {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [TestenvConfigs] $Configs,
        [Parameter(Mandatory=$true)] [Network[]] $Networks
    )

    Initialize-ComputeServices -Session $Session `
        -SystemConfig $Configs.System `
        -OpenStackConfig $Configs.OpenStack `
        -ControllerConfig $Configs.Controller

    foreach ($Network in $Networks) {
        $ID = New-DockerNetwork -Session $Session `
            -TenantName $Configs.Controller.DefaultProject `
            -Name $Network.Name `
            -Subnet "$( $Network.Subnet.IpPrefix )/$( $Network.Subnet.IpPrefixLen )"

        Write-Log "Created network id: $ID"
    }
}
