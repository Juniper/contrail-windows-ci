. $PSScriptRoot\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\CIScripts\Common\Invoke-NativeCommand.ps1
. $PSScriptRoot\..\PesterLogger\PesterLogger.ps1

$DockerfilesPath = "$PSScriptRoot\..\DockerFiles\"

function Test-Dockerfile {
    Param ([Parameter(Mandatory = $true)] [string] $DockerImageName)

    Test-Path (Join-Path $DockerfilesPath $DockerImageName)
}

function Initialize-DockerImage  {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $DockerImageName
    )

    $DockerfilePath = $DockerfilesPath + $DockerImageName
    $TestbedDockerfilesDir = "C:\DockerFiles\"
    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Force $Using:TestbedDockerfilesDir | Out-Null
    }

    Write-Log "Copying directory with Dockerfile"
    Copy-Item -ToSession $Session -Path $DockerfilePath -Destination $TestbedDockerfilesDir -Recurse -Force

    Write-Log "Building Docker image"
    $TestbedDockerfilePath = $TestbedDockerfilesDir + $DockerImageName

    $MaxNumRetries = 5
    foreach ($i in 1..$MaxNumRetries) {
        # This retry loop is a workaround for a "container <hash> encountered an error during Start:
        # failure in a Windows system call: This operation returned because the timeout period expired".
        # This is probably caused by slow disks or other windows error. See:
        # https://github.com/MicrosoftDocs/Virtualization-Documentation/issues/575
        # https://github.com/moby/moby/issues/27588

        $Command = Invoke-NativeCommand -Session $Session -CaptureOutput -AllowNonZero -ScriptBlock {
            docker build -t $Using:DockerImageName $Using:TestbedDockerfilePath
        }

        if ($Command.ExitCode -eq 0) {
            break
        }

        $IsTimeoutFlake = $Command.Output -Match ".*container.*encountered an error during Start.*0x5b4.*"
        if (($i -ne $MaxNumRetries) -and $IsTimeoutFlake) {
            Write-Log "Retrying due to following error: $( $Command.Output )"
            continue
        }

        throw "docker build failed: $( $Command.Output )"
    }
}
