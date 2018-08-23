function Resolve-BuildMode {
    #Helper function to verify in what build configuration/mode
    #(release/production or debug) Windows compute node components will be built.
    Write-Host $Env:BUILD_IN_RELEASE_MODE

    $IsReleaseMode = [bool]::Parse($Env:BUILD_IN_RELEASE_MODE)
    $BuildMode = $(if ($IsReleaseMode) { "production" } else { "debug" })

    return $BuildMode
}
