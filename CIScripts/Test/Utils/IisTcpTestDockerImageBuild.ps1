. $PSScriptRoot\..\..\Common\Aliases.ps1
$DockerfilePath = "$PSScriptRoot\..\..\DockerFiles\iis-tcptest\Dockerfile"

function Initialize-IisTcpTestDockerImage  {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    $DockerFilesDir = "C:\DockerFiles"
    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Force $Using:DockerImagesDir | Out-Null
    }

    Write-Host "Copying iis-tcp-test image Dockerfile"
    Copy-Item -ToSession $Session -Path $DockerfilePath -Destination $DockerFilesDir

    Write-Host "Building iis-tcptest Docker image"
    Invoke-Command -Session $Session -ScriptBlock {
        docker build -t iis-tcptest $Using:DockerFilesDir
    }
}
