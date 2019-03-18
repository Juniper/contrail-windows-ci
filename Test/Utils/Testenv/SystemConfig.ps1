class SystemConfig {
    [string] $VHostName
    [string] $ForwardingExtensionName

    static [SystemConfig] LoadFromFile([string] $Path) {
        $Parsed = Read-TestenvFile($Path)
        return [SystemConfig] $Parsed.System
    }
}
