Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile
)

. $PSScriptRoot\IisTcpTestDockerImageBuild.ps1

$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]

Describe "Initialize-IisTcpTestDockerImage" {
    It "Builds iis-tcptest image" {
        { Initialize-IisTcpTestDockerImage -Session $Session } | Should Not Throw

        Invoke-Command -Session $Session {
            docker inspect iis-tcptest
        } | Should Not BeNullOrEmpty
    }

    BeforeEach {
        Invoke-Command -Session $Session {
            docker image rm iis-tcptest -f
        }
    }
}
