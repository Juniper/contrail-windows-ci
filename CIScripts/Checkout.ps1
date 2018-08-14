. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Checkout\Zuul.ps1

$Job = [Job]::new("Checkout")

if (Test-Path "Env:ZUUL_URL") {
    Get-ZuulRepos -GerritUrl $Env:GERRIT_URL `
                  -ZuulProject $Env:ZUUL_PROJECT `
                  -ZuulRef $Env:ZUUL_REF `
                  -ZuulUrl $Env:ZUUL_URL `
                  -ZuulBranch $Env:ZUUL_BRANCH
} else {
    Get-ZuulRepos -GerritUrl $Env:GERRIT_URL
}

$Job.Done()
