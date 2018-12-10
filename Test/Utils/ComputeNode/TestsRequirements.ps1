. $PSScriptRoot\..\..\CIScripts\Common\Invoke-NativeCommand.ps1

function Get-DockerfilesPath {
    return 'C:\DockerFiles'
}

function Get-DNSDockerName {
    return 'python-dns'
}
function Deploy-MicrosoftDockerImages {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )
    Write-Log 'Downloading Docker images'
    $StartedJobs = @()
    ForEach ($Session in $Sessions) {
        $JobName = "$($session.ComputerName)-pulldockerms"
        Invoke-Command -Session $Session -JobName $JobName -AsJob {
            docker pull microsoft/windowsservercore
            docker pull microsoft/nanoserver
        } | Out-Null
        $StartedJobs += $JobName
    }
    ForEach ($StartedJob in $StartedJobs) {
        Wait-Job -Name $StartedJob | Out-Null
        $Result = Receive-Job -Name $StartedJob
        Write-Log "Job '$StartedJob' result: $Result"
    }
}

function Install-DNSTestDependencies {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )
    $DNSDockerfilePath = Join-Path (Get-DockerfilesPath) (Get-DNSDockerName)
    foreach ($Session in $Sessions) {
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
        }
        else {
            Write-Log 'DNS test dependencies installed successfully'
        }
    }
}
