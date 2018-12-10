. $PSScriptRoot\..\..\CIScripts\Common\Invoke-NativeCommand.ps1

function Get-DockerfilesPath {
    return 'C:\DockerFiles'
}

function Get-DNSDockerName {
    return 'python-dns'
}
function Initialize-Testbeds {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )
    foreach($Session in $Sessions) {
        Write-Log 'Downloading Docker images'
        $Result = Invoke-NativeCommand -Session $Session -CaptureOutput -AllowNonZero {
            docker pull microsoft/windowsservercore
        }
        Write-Log $Result.Output
        $Result = Invoke-NativeCommand -Session $Session -CaptureOutput -AllowNonZero {
            docker pull microsoft/nanoserver
        }
        Write-Log $Result.Output
    }
}

function Install-DNSTestDependencies {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )
    $DNSDockerfilePath = Join-Path (Get-DockerfilesPath) (Get-DNSDockerName)
    foreach($Session in $Sessions) {
        Write-Log 'Configuring dependencies for DNS tests'
        $Result = Invoke-NativeCommand -Session $Session -AllowNonZero -CaptureOutput {
            New-Item -ItemType directory -Path $Using:DNSDockerfilePath -Force
            pip  download dnslib==0.9.7 --dest $Using:DNSDockerfilePath
            pip  install dnslib==0.9.7
            pip  install pathlib==1.0.1
        }
        Write-Log $Result.Output
        if ($Result.ExitCode -ne 0) {
            Write-Warning 'Installing DNS test dependecies failed'
        } else {
            Write-Log 'DNS test dependencies installed successfully'
        }
    }
}
