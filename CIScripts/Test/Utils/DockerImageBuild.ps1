. $PSScriptRoot\..\..\Common\Aliases.ps1
$DockerfilesPath = "$PSScriptRoot\..\..\DockerFiles\"

function Initialize-DockerImage  {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session
           [Parameter(Mandatory = $true)] [string] $DockerImageName)

    $DockerfilePath = $DockerfilesPath + $DockerImageName
    $TestbedDockerfilesDir = "C:\DockerFiles\"
    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Force $Using:TestbedDockerfilesDir | Out-Null
    }

    Write-Host "Copying directory with Dockerfile"
    Copy-Item -ToSession $Session -Path $DockerfilePath -Destination $TestbedDockerfilesDir -Recurse -Force

    Write-Host "Building iis-tcptest Docker image"
    Invoke-Command -Session $Session -ScriptBlock {
        docker build -t $DockerImageName ($Using:TestbedDockerfilesDir + $Using:DockerImageName)
    }
}
