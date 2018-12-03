class ProjectRepo : BaseRepo {
    [String] $ResourceName = 'project'

    ProjectRepo([ContrailNetworkManager] $API) : base($API) {}

    [PSobject] GetAddRequest([Project] $Project) {
        return @{
            "project" = @{
                fq_name = $Project.GetFQName()
            }
        }
    }

    [void] RemoveDependencies([Project] $Project) {
        $Uuid = $this.API.FQNameToUuid($this.ResourceName, $Project.GetFQName())
        $ProjectResponse = $this.API.Get($this.ResourceName, $Uuid, $null)
        $Props = $ProjectResponse.'project'.PSobject.Properties.Name

        if($Props -contains 'security_groups') {
            ForEach ($SecurityGroup in $ProjectResponse.'project'.'security_groups') {
                $this.API.Delete('security-group', $SecurityGroup.'uuid', $null)
            }
        }
    }
}
