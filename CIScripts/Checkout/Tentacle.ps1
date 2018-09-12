function Get-TentacleRepos {
    Param (
        [Parameter(Mandatory = $true)] [string] $ArchiveUrl
    )

    $Job.Step("Downloading tentacle repositories", {
        Invoke-WebRequest -Uri $ArchiveUrl -OutFile repos.zip
    })

    $Job.Step("Unpacking tentacle repositories", {
        Expand-Archive -Path repos.zip
    })
}
