Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile
)

. $PSScriptRoot\IisTcpTestDockerImageBuild.ps1

$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]
Describe "Initialize-IisTcpTestDockerImage" {
    It "Builds iis-tcptest image" {
        { Initialize-IisTcpTestDockerImage -Session $Session } | Should Not Throw
    }
    
    It "iis-tcptest image appear in docker inspect" {
        Invoke-Command -Session $Session {
            { docker inspect iis-tcptest } | Should Not BeNullOrEmpty
        }
    }
}
