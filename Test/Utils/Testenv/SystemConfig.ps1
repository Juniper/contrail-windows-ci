class SystemConfig {
    [string] $DataAdapterName
    [string] $VHostName
    [string] $ForwardingExtensionName

    [string] VMSwitchName() {
        return "Layered " + $this.DataAdapterName
    }

    static [SystemConfig] LoadFromFile([string] $Path) {
        $Parsed = Read-TestenvFile($Path)
        return [SystemConfig] $Parsed.System
    }
}
