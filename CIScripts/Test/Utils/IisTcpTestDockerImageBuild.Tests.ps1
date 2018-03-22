Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile
)

. $PSScriptRoot\IisTcpTestDockerImageBuild.ps1

$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]
Describe "Initialize-IisTcpTestDockerImageBuild" {
    It "builds iis-tcptest image" {
        Initialize-IisTcpTestDockerImageBuild -Session $Session
    } | Should Be 0
}
