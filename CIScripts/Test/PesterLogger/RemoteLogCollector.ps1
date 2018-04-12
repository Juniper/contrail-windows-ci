function New-TrackedLogSource {
    Param([Parameter(Mandatory = $true)] [string] $Path,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

    $Sources = @()

    $Sessions | ForEach-Object {
        $Session = $_

        if ($Session) {
            $SourceHost = $Session.ComputerName
        } else {
            $SourceHost = "localhost"
        }

        $ContentGetterBody = {
            Param([Parameter(Mandatory = $true)] [string] $From)
            $Files = Get-ChildItem -Path $From -ErrorAction SilentlyContinue
            $Logs = @{}
            if (-not $Files) {
                $Logs[$From] = "WARNING: FILE NOT FOUND"
            } else {
                $Files | ForEach-Object {
                    $Content = Get-Content -Raw $_
                    $Logs[$_.FullName] = $Content
                }
            }
            return $Logs
        }
        $ContentGetter = New-RemoteOrLocalClosure -Func $ContentGetterBody -Session $Session -Arguments $Path

        $LogCleanerBody = {
            Param([Parameter(Mandatory = $true)] [string] $What)
            $Files = Get-ChildItem -Path $What -ErrorAction SilentlyContinue
            $Files | ForEach-Object {
                Remove-Item $What
            }
        }
        $LogCleaner = New-RemoteOrLocalClosure -Func $LogCleanerBody -Session $Session -Arguments $Path

        $SingleSource = @{
            ContentGetter = $ContentGetter
            LogCleaner = $LogCleaner
            SourceHost = $SourceHost
            SourcePath = $Path
        }

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "Sources",
            Justification="Seems like ForEach block messes up static analysis here - this var is" +
                "already declared before the loop"
        )]
        $Sources += $SingleSource
    }

    return $Sources
}

function New-RemoteOrLocalClosure {
    param([ScriptBlock] $Func, [PSSessionT] $Session, [Object[]] $Arguments) 
    if ($Session) {
        $Closure = {
            Invoke-Command -Session $Script:Session $Func -ArgumentList $Arguments
        }.GetNewClosure()
    } else {
        $Closure = {
            Invoke-Command $Func -ArgumentList $Arguments
        }.GetNewClosure()
    }
    return $Closure
}
