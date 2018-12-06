class Project : BaseResourceModel {
    [string] $Name
    [string] $DomainName = 'default-domain'

    Project([String] $Name) {
        $this.Name = $Name

        $this.Dependencies += [Dependency]::new('security-group', 'security_groups')
    }

    [String[]] GetFQName() {
        return @($this.DomainName, $this.Name)
    }

    [String] $ResourceName = 'project'
    [String] $ParentType = 'domain'

    [PSobject] GetRequest() {
        return @{
            'project' = @{}
        }
    }
}
