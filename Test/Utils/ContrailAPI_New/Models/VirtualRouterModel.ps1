class VirtualRouter : BaseModel {
    [string] $Name;
    [string] $Ip;
    [string] $ParentName = 'default-global-system-config';

    VirtualRouter([String] $Name, [String] $Ip) {
        $this.Name = $Name
        $this.Ip = $Ip
    }

    [String[]] GetFQName() {
        return @($this.ParentName, $this.Name)
    }
}
