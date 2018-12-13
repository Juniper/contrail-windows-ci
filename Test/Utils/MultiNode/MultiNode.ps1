. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\ContrailAPI_New\ContrailAPI.ps1

class MultiNode {
    [ContrailNetworkManager] $NM
    [ContrailRestApi] $ContrailRestApi
    [TestenvConfigs] $Configs
    [PSSessionT[]] $Sessions
    [VirtualRouter[]] $VRouters
    [Project] $Project

    MultiNode([ContrailNetworkManager] $NM,
        [ContrailRestApi] $ContrailRestApi,
        [TestenvConfigs] $Configs,
        [PSSessionT[]] $Sessions,
        [VirtualRouter[]] $VRouters,
        [Project] $Project) {

        $this.NM = $NM
        $this.ContrailRestApi = $ContrailRestApi
        $this.Configs = $Configs
        $this.Sessions = $Sessions
        $this.VRouters = $VRouters
        $this.Project = $Project
    }
}
