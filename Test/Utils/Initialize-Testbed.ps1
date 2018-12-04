function Get-DockerfilesPath {
    return "C:\DockerFiles"
}

function Get-DNSDockerName {
    return "python-dns"
}
function Initialize-Testbeds {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )
    foreach($Session in $Sessions) {
        Write-Log "Downloading Docker images."
        Invoke-Command -Session $Session -ScriptBlock {
            docker pull microsoft/windowsservercore
            docker pull microsoft/nanoserver
        } | Out-Null
    }
}

function Install-DNSTestDependencies {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )
    $DNSDockerfilePath = Join-Path (Get-DockerfilesPath) (Get-DNSDockerName)
    foreach($Session in $Sessions) {
        Write-Log "Configuring dependencies for DNS tests"
        Invoke-Command -Session $Session -ScriptBlock {
            New-Item -ItemType directory -Path $Using:DNSDockerfilePath -Force | Out-Null
            pip -qq download dnslib==0.9.7 --dest $Using:DNSDockerfilePath
            pip -qq install dnslib==0.9.7
            pip -qq install pathlib==1.0.1
        } | Out-Null
}