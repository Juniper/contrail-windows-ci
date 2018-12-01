class Project : BaseModel {
    [string] $Name;
    [string] $DomainName = 'default-domain';

    Project([String] $Name) {
        $this.Name = $Name
    }

    [String[]] GetFQName() {
        return @($this.DomainName, $this.Name)
    }
}
