Param(
    [Parameter(Mandatory = $true)] [string] $TestenvConfFile,
    [Parameter(Mandatory = $true)] [string] $ArtifactsDir
)

# Deploy copies required artifacts onto already provisioned machines.

. $Env:COMMON_POWERSHELL_CODE\Init.ps1
. $Env:COMMON_POWERSHELL_CODE\Job.ps1
. $PSScriptRoot\..\Test\Utils\Testenv\Testbed.ps1
. $PSScriptRoot\Deploy\Deployment.ps1

$Job = [Job]::new("Deploy")

$Sessions = New-RemoteSessions -VMs ([Testbed]::LoadFromFile($TestenvConfFile))
Copy-ArtifactsToTestbeds -Sessions $Sessions -ArtifactsDir $ArtifactsDir

$Job.Done()

exit 0
