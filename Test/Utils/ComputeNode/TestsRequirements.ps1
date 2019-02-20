. $PSScriptRoot\..\..\Utils\PowershellTools\Invoke-NativeCommand.ps1

function Get-DockerfilesPath {
    return 'C:\DockerFiles'
}

function Get-DNSDockerName {
    return 'python-dns'
}
function Sync-MicrosoftDockerImagesOnTestbeds {
    Param (
        [Parameter(Mandatory = $true)] [Testbed[]] $Testbeds
    )
    Write-Log 'Downloading Docker images'
    $StartedJobs = @()
    ForEach ($Testbed in $Testbeds) {
        $JobName = "$($Testbed.GetSession().ComputerName)-pulldockerms"
        Invoke-Command -Session $Testbed.GetSession() -JobName $JobName -AsJob {
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
        if (0 -ne $Result.ExitCode) {
            Write-Warning 'Installing DNS test dependecies failed'
        }
        else {
            Write-Log 'DNS test dependencies installed successfully'
        }
    }
}
