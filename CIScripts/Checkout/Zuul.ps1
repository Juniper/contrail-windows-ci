. $PSScriptRoot\..\Common\Invoke-NativeCommand.ps1

function Get-ZuulRepos {
    Param (
        [Parameter(Mandatory = $true)] [string] $GerritUrl,
        [Parameter(Mandatory = $false)] [string] $ZuulProject,
        [Parameter(Mandatory = $false)] [string] $ZuulRef,
        [Parameter(Mandatory = $false)] [string] $ZuulUrl,
        [Parameter(Mandatory = $false)] [string] $ZuulBranch
    )

    $ZuulClonerOptions = @(
        "--map=./CIScripts/clonemap.yml",
        $GerritUrl
    )

    if ($ZuulUrl -ne "") {
        $ZuulClonerOptions = @(
            "--zuul-project=$ZuulProject",
            "--zuul-ref=$ZuulRef",
            "--zuul-url=$ZuulUrl",
            "--zuul-branch=$ZuulBranch"
        ) + $ZuulClonerOptions
    }

    # TODO(sodar): Get project list from clonemap.yml
    $ProjectList = @(
        "Juniper/contrail-api-client",
        "Juniper/contrail-build",
        "Juniper/contrail-controller",
        "Juniper/contrail-vrouter",
        "Juniper/contrail-third-party",
        "Juniper/contrail-common",
        "Juniper/contrail-windows-docker-driver",
        "Juniper/contrail-windows"
    )

    $Job.Step("Cloning zuul repositories", {
        Invoke-NativeCommand -ScriptBlock {
            zuul-cloner.exe @ZuulClonerOptions @ProjectList
        }
    })
}
