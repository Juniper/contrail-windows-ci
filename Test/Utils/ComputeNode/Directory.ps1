. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1

function Assert-DirExists {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [string] $DirPath
    )

    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Path $using:DirPath -Force | Out-Null
    } | Out-Null
}

function Assert-LogDirExists {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session
    )

    Assert-DirExists -Session $Session -DirPath $(Get-DefaultConfigDir)
}

function Assert-ConfigDirExists {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session
    )

    Assert-DirExists -Session $Session -DirPath $(Get-ComputeLogsDir)
}

function Assert-ConfAndLogDirExist {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions
    )

    foreach($Session in $Sessions) {
        Assert-ConfigDirExists -Session $Session
        Assert-LogDirExists -Session $Session
    }
}
