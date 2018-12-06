class Project : BaseResourceModel {
    [String] $Name
    [String] $DomainName = 'default-domain'

    Project([String] $Name) {
        $this.Name = $Name

        $this.Dependencies += [Dependency]::new('security-group', 'security_groups')
    }

    [String[]] GetFqName() {
        return @($this.DomainName, $this.Name)
    }

    [String] $ResourceName = 'project'
    [String] $ParentType = 'domain'

    [Hashtable] GetRequest() {
        return @{
            'project' = @{}
        }
    }
}
