. $PSScriptRoot\..\..\..\CIScripts\Common\Invoke-NativeCommand.ps1

function Remove-AllContainers {
    Param ([Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions)

    foreach ($Session in $Sessions) {
        $Result = Invoke-NativeCommand -Session $Session -CaptureOutput -AllowNonZero {
            $Containers = docker ps -aq
            $MaxAttempts = 3
            $TimesToGo = $MaxAttempts
            while ( $Containers -and $TimesToGo -gt 0 ) {
                if($Containers) {
                    $Command = "docker rm -f $Containers"
                    Invoke-Expression -Command $Command
                }
                $Containers = docker ps -aq
                $TimesToGo = $TimesToGo - 1
                if ( $Containers -and 0 -eq $TimesToGo ) {
                    $LASTEXITCODE = 1
                }
            }
            Remove-Variable "Containers"
            return $MaxAttempts - $TimesToGo - 1
        }

        $OutputMessages = $Result.Output
        if (0 -ne $Result.ExitCode) {
            throw "Remove-AllContainers - removing containers failed with the following messages: $OutputMessages"
        } elseif ($Result.Output[-1] -gt 0) {
            Write-Host "Remove-AllContainers - removing containers was successful, but required more than one attempt: $OutputMessages"
        }
    }
}

function Remove-Container {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $false)] [string] $NameOrId)

    Invoke-Command -Session $Session -ScriptBlock {
        docker rm -f $Using:NameOrId | Out-Null
    }
}


function New-Container {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $NetworkName,
           [Parameter(Mandatory = $false)] [string] $Name,
           [Parameter(Mandatory = $false)] [string] $Image = "microsoft/nanoserver",
           [Parameter(Mandatory = $false)] [string] $IP)

    if (Test-Dockerfile $Image) {
        Initialize-DockerImage -Session $Session -DockerImageName $Image | Out-Null
    }

    $Arguments = "run", "-di"
    if ($Name) { $Arguments += "--name", $Name }
    if ($IP) { $Arguments += "--ip", $IP }
    $Arguments += "--network", $NetworkName, $Image

    $Result = Invoke-NativeCommand -Session $Session -CaptureOutput -AllowNonZero { docker @Using:Arguments }
    $ContainerID = $Result.Output[0]
    $OutputMessages = $Result.Output

    # Workaround for occasional failures of container creation in Docker for Windows.
    # In such a case Docker reports: "CreateContainer: failure in a Windows system call",
    # container is created (enters CREATED state), but is not started and can not be
    # started manually. It's possible to delete a faulty container and start it again.
    # We want to capture just this specific issue here not to miss any new problem.
    if ($Result.Output -match "CreateContainer: failure in a Windows system call") {
        Write-Log "Container creation failed with the following output: $OutputMessages"
        Write-Log "Removing incorrectly created container (if exists)..."
        Invoke-NativeCommand -Session $Session -AllowNonZero { docker rm -f $Using:ContainerID } | Out-Null
        Write-Log "Retrying container creation..."
        $ContainerID = Invoke-Command -Session $Session { docker @Using:Arguments }
    } elseif (0 -ne $Result.ExitCode) {
        throw "New-Container failed with the following output: $OutputMessages"
    }

    return $ContainerID
}
