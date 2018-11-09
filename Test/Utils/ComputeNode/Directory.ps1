. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1

function Set-DirExists {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [string] $DirPath
    )

    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Path $using:DirPath -Force | Out-Null
    } | Out-Null
}

function Set-LogDirExists {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session
    )

    Set-DirExists -Session $Session -DirPath $(Get-DefaultConfigDir)
}

function Set-ConfigDirExists {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session
    )

    Set-DirExists -Session $Session -DirPath $(Get-ComputeLogsDir)
}

function Set-ConfAndLogDirExist {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )

    foreach($Session in $Sessions) {
        Set-ConfigDirExists -Session $Session
        Set-LogDirExists -Session $Session
    }
}
