. $PSScriptRoot/../../Common/Aliases.ps1

. $PSScriptRoot/Get-CurrentPesterScope.ps1

function Initialize-PesterLogger {
    Param([Parameter(Mandatory = $true)] [string] $Outdir,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

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
        Param([Parameter(Mandatory = $true)] [string] $From,
              [Parameter(Mandatory = $false)] [switch] $DontCleanUp)
        $Script:Sessions | ForEach-Object {
            $Session = $_
            $ComputerNamePrefix = "Logs from $($_.ComputerName): "
            Write-Log ((@("=") * $ComputerNamePrefix.Length) -join "")
            Write-Log $ComputerNamePrefix

            $Files = Get-ChildItem -Path $From -ErrorAction SilentlyContinue
            if (-not $Files) {
                Write-Log "!!!! Warning: FILES AT $FROM NOT FOUND"
            }
            $Files | ForEach-Object {
                $CurrentSourceFile = $_
                $SourceFilenamePrefix = "Contents of $($_.FullName):"
                Write-Log ((@("-") * $SourceFilenamePrefix.Length) -join "")
                Write-Log $SourceFilenamePrefix

                $Content = Invoke-Command -Session $Session {
                    Get-Content -Raw $Using:CurrentSourceFile
                }
                Write-Log $Content

                if (-not $DontCleanUp) {
                    Invoke-Command -Session $Session {
                        Remove-Item $Using:CurrentSourceFile
                    }
                }
            }
        }
    }.GetNewClosure()

    Register-NewFunc -Name "Move-Logs" -Func $MoveLogsFunc
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
