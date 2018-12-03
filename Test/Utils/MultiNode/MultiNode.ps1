. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\ContrailAPI_New\VirtualRouter.ps1
. $PSScriptRoot\..\ContrailAPI_New\Project.ps1

class MultiNode {
    [ContrailNetworkManager] $NM
    [TestenvConfigs] $Configs
    [PSSessionT[]] $Sessions
    [VirtualRouter[]] $VRouters
    [Project] $Project

    MultiNode([ContrailNetworkManager] $NM,
              [TestenvConfigs] $Configs,
              [PSSessionT[]] $Sessions,
              [VirtualRouter[]] $VRouters,
              [Project] $Project) {
        $this.NM = $NM
        $this.Configs = $Configs
        $this.Sessions = $Sessions
        $this.VRouters = $VRouters
        $this.Project = $Project
    }
}
