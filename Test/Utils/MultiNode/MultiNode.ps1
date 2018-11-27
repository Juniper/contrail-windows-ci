. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1

class MultiNode {
    [ContrailNetworkManager] $NM;
    [TestenvConfigs] $Configs;
    [PSSessionT[]] $Sessions;
    [String[]] $VRoutersUuids;

    MultiNode([ContrailNetworkManager] $NM,
              [TestenvConfigs] $Configs,
              [PSSessionT[]] $Sessions,
              [String[]] $VRoutersUuids) {
        $this.NM = $NM
        $this.Configs = $Configs
        $this.Sessions = $Sessions
        $this.VRoutersUuids = $VRoutersUuids
    }
}
