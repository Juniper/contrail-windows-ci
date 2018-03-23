. $PSScriptRoot\..\..\Common\Aliases.ps1
$DockerfilePath = "$PSScriptRoot\..\..\DockerImages\iis-tcptest\Dockerfile"
function Initialize-IisTcpTestDockerImage  {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    $DockerImagesDir = "C:\DockerImages"
    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Force $Using:DockerImagesDir | Out-Null
    }

    Write-Host "Copying iis-tcp-test image Dockerfile"
    Copy-Item -ToSession $Session -Path $DockerfilePath -Destination $DockerImagesDir

    Write-Host "Building iis-tcptest Docker image"
    $Res = Invoke-Command -Session $Session -ScriptBlock {
        docker build -t iis-tcptest $Using:DockerImagesDir
        return $LASTEXITCODE
    }
    return $Res
}
