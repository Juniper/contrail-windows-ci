function Get-TentacleRepos {
    Param (
        [Parameter(Mandatory = $true)] [string] $ArchiveUrl
    )

    $Job.Step("Getting tentacle repositories", {
        Invoke-WebRequest -Uri $ArchiveUrl -OutFile repos.zip
        Expand-Archive -Path repos.zip
    })
}
