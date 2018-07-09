. $PSScriptRoot/Aliases.ps1
function Invoke-CommandWithFunctions {
    Param(
        [Parameter(Mandatory=$true)] [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [PSCustomObject] $FunctionsInvoked,
        [Switch] $CaptureOutput
    )

    Invoke-Command -Session $Session -ScriptBlock {
        $Using:FunctionsInvoked | ForEach-Object { Invoke-Expression "function $( $_.Name ) { $( $_.Body ) }" }
    }

    $Output = Invoke-Command -Session $Session -ScriptBlock $ScriptBlock

    Invoke-Command -Session $Session -ScriptBlock {
        $Using:FunctionsInvoked | ForEach-Object { Remove-Item -Path "Function:$( $_.Name )" }
    }

    return $Output
}
