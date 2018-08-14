. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Checkout\Zuul.ps1

$Job = [Job]::new("Checkout")

$defaults = @{
    GERRIT_URL = "https://review.opencontrail.org"
    ZUUL_PROJECT = "controller"
    ZUUL_REF = "None"
    ZUUL_URL = "https://review.opencontrail.org"
    ZUUL_BRANCH = "master"
}

ForEach ($elem in $defaults.GetEnumerator()) {
    $envVarName = "Env:$($elem.Key)"
    if (Test-Path $envVarName) {
        $value = (Get-ChildItem $envVarName).Value
    } else {
        $value = $elem.Value
    }
    Set-Variable -Name $elem.Key -Value $value
}

Get-ZuulRepos -GerritUrl $GERRIT_URL `
              -ZuulProject $ZUUL_PROJECT `
              -ZuulRef $ZUUL_REF `
              -ZuulUrl $ZUUL_URL `
              -ZuulBranch $ZUUL_BRANCH

$Job.Done()
