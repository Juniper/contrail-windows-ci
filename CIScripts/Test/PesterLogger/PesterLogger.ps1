. $PSScriptRoot/../../Common/Aliases.ps1

. $PSScriptRoot/Get-CurrentPesterScope.ps1
. $PSScriptRoot/RemoteLogCollector.ps1

function Initialize-PesterLogger {
    Param([Parameter(Mandatory = $true)] [string] $Outdir,
          [Parameter(Mandatory = $false)] [System.Collections.Hashtable[]] $LogSources)

    # Closures don't capture functions, so we need to capture them as variables.
    $WriterFunc = Get-Item function:Add-ContentForce
    $DeducerFunc = Get-Item function:Get-CurrentPesterScope

    if (-not (Test-Path $Outdir)) {
        New-Item -Force -Path $Outdir -Type Directory
    }
    # This is so we can change location in our test cases but it won't affect location of logs.
    $ConstOutdir = Resolve-Path $Outdir

    $WriteLogFunc = {
        Param([Parameter(Mandatory = $true)] [string] $Message)
        $Scope = & $DeducerFunc
        $Filename = ($Scope -join ".") + ".log"
        $Outpath = Join-Path $Script:ConstOutdir $Filename
        & $WriterFunc -Path $Outpath -Value $Message
    }.GetNewClosure()

    Register-NewFunc -Name "Write-Log" -Func $WriteLogFunc

    $MoveLogsFunc = {
        Param([Parameter(Mandatory = $false)] [switch] $DontCleanUp)

        $Script:LogSources | ForEach-Object {
            $LogSource = $_
            $ComputerNamePrefix = "Logs from $($LogSource.SourceHost): "
            Write-Log ((@("=") * $ComputerNamePrefix.Length) -join "")
            Write-Log $ComputerNamePrefix

            $Logs = & $LogSource.ContentGetter
            $Logs.Keys | ForEach-Object {
                $Filename = $_
                $Content = $Logs[$Filename]
                $SourceFilenamePrefix = "Contents of $($Filename):"

                Write-Log ((@("-") * $SourceFilenamePrefix.Length) -join "")
                Write-Log $SourceFilenamePrefix
                Write-Log $Content
            }
            
            if (-not $DontCleanUp) {
                & $LogSource.LogCleaner 
            }
        }
    }.GetNewClosure()

    Register-NewFunc -Name "Merge-TrackedLogs" -Func $MoveLogsFunc
}

function Add-ContentForce {
    Param([Parameter(Mandatory = $true)] [string] $Path,
          [Parameter(Mandatory = $true)] [string] $Value)
    if (-not (Test-Path $Path)) {
        New-Item -Force -Path $Path -Type File | Out-Null
    }
    Add-Content -Path $Path -Value $Value | Out-Null
}

function Register-NewFunc {
    Param([Parameter(Mandatory = $true)] [string] $Name,
          [Parameter(Mandatory = $true)] [ScriptBlock] $Func)
    if (Get-Item function:$Name -ErrorAction SilentlyContinue) {
        Remove-Item function:$Name
    }
    New-Item -Path function:\ -Name Global:$Name -Value $Func | Out-Null
}
