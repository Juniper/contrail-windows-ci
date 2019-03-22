. $PSScriptRoot\..\..\Test\Utils\PowershellTools\Aliases.ps1

function Copy-ArtifactsToTestbeds {
    Param ([Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions,
           [Parameter(Mandatory = $true)] [string] $ArtifactsDir)
    $Job.Step("Deploying testbeds", {
        $Sessions.ForEach({
            $Job.Step("Deploying testbed...", {
                Install-Artifacts -Session $_ -ArtifactsDir $ArtifactsDir
            })
        })
    })
}

function Install-Artifacts {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $ArtifactsDir)

    function Test-NonemptyDir {
        Param ([Parameter(Mandatory = $true)] [string] $Path)
        [bool](Get-ChildItem $Path -ErrorAction SilentlyContinue)
    }

    Push-Location $ArtifactsDir

    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Force 'C:\Artifacts' | Out-Null
    }

    if (Test-NonemptyDir "cnm-plugin") {
        Invoke-Command -Session $Session -ScriptBlock {
            New-Item -ItemType Directory -Force 'C:\Artifacts\cnm-plugin' | Out-Null
        }

        Write-Host "Copying CNM plugin installer"
        Copy-Item -ToSession $Session -Path "cnm-plugin\contrail-cnm-plugin.msi" -Destination 'C:\Artifacts\cnm-plugin\'

        Write-Host "Copying CNM plugin tests"
        Copy-Item -ToSession $Session -Path "cnm-plugin\*.test.exe" -Destination 'C:\Artifacts\cnm-plugin\'
    }

    if (Test-NonemptyDir "agent") {
        Invoke-Command -Session $Session -ScriptBlock {
            New-Item -ItemType Directory -Force 'C:\Artifacts\agent' | Out-Null
        }

        Write-Host "Copying Agent"
        Copy-Item -ToSession $Session -Path "agent\contrail-vrouter-agent.msi" -Destination 'C:\Artifacts\agent\'
    }

    if (Test-NonemptyDir "vrouter") {
        Invoke-Command -Session $Session -ScriptBlock {
            New-Item -ItemType Directory -Force 'C:\Artifacts\vrouter' | Out-Null
        }

        Write-Host "Copying vRouter and Utils MSIs"
        Copy-Item -ToSession $Session -Path "vrouter\vRouter.msi" -Destination 'C:\Artifacts\vrouter\'
        Copy-Item -ToSession $Session -Path "vrouter\utils.msi" -Destination 'C:\Artifacts\vrouter\'
        Copy-Item -ToSession $Session -Path "vrouter\*.cer" -Destination 'C:\Artifacts\vrouter\' # TODO: Remove after JW-798
    }

    if (Test-NonemptyDir "vtest") {
        Write-Host "Copying vtest scenarios"
        Copy-Item -ToSession $Session -Path "vtest" -Destination C:\Artifacts\ -Recurse -Force
    }

    if (Test-NonemptyDir "nodemgr") {
        Write-Host "Copying Node Manager"
        Copy-Item -ToSession $Session -Path "nodemgr" -Destination C:\Artifacts\ -Recurse
    }

    if (Test-NonemptyDir "dlls") {
        Write-Host "Copying dlls"
        Copy-Item -ToSession $Session -Path "dlls\*" -Destination "C:\Windows\System32\"
    }

    Invoke-Command -Session $Session -ScriptBlock {
        # Refresh Path
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    }

    Pop-Location
}
