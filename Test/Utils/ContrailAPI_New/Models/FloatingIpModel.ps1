class FloatingIp : BaseRepoModel {
    [string] $Name
    [string[]] $PoolFqName
    [string] $Address
    [string[][]] $PortFqNames

    FloatingIp([string] $Name, [string[]] $PoolFqName, [string] $Address) {
        $this.Name = $Name
        $this.PoolFqName = $PoolFqName
        $this.Address = $Address
    }

    [String[]] GetFQName() {
        return ($this.PoolFqName + @($this.Name))
    }
}
