class ControllerConfig {
    [string] $Address
    [int] $RestApiPort
    [string] $AuthMethod

    [string] RestApiUrl() {
        return "http://$( $this.Address ):$( $this.RestApiPort )"
    }

    static [ControllerConfig] LoadFromFile([string] $Path) {
        $Parsed = Read-TestenvFile($Path)
        return [ControllerConfig] $Parsed.Controller
    }
}
