Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile
)

. $PSScriptRoot\IisTcpTestDockerImageBuild.ps1

$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]

Describe "Initialize-IisTcpTestDockerImage" {
    It "Builds iis-tcptest image" {
        Initialize-DockerImage -Session $Session

        Invoke-Command -Session $Session {
            docker inspect iis-tcptest
        } | Should Not BeNullOrEmpty
    }

    BeforeEach {
        # Invoke-Command used as a workaround for temporary ErrorActionPreference modification
        Invoke-Command -Session $Session {
            Invoke-Command {
                $ErrorActionPreference = "SilentlyContinue"
                docker image rm iis-tcptest -f 2>$null
            }
        }
    }
}
