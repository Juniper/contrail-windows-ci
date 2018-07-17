. $PSScriptRoot/Aliases.ps1
function Invoke-CommandWithFunctions {
    <#
    .SYNOPSIS
    This is a helper function for using locally defined functions in remote session.
    The problem is that PowerShell does not support passing functions
    to remote session, like ScriptBlocks or locally defined variables (by "$using:")
    What Invoke-CommandWithFunctions do is just taking functions names and bodies 
    and define them at remote session by using Invoke-Expression.
    Then we invoke ScriptBlock with calls to already defined functions
    After we remove the definitions from remote session memory so we do not pollute it.
    .PARAMETER ScriptBlock
    ScriptBlock with functions calls to invoke.
    .PARAMETER Session
    Remote session where the Scriptblock will be invoked.
    .PARAMETER Functions
    Names of functions called in ScriptBlock
    .PARAMETER CaptureOutput
    If set, output from invoking ScriptBlock will be saved to a variable and returned
    If not, output is printed to stdout.
    #>
    Param(
        [Parameter(Mandatory=$true)] [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [string[]] $Functions,
        [Switch] $CaptureOutput
    )

    $FunctionsInvoked = $Functions `
        | ForEach-Object { @{ Name = $_; Body = Get-Content function:$_ } }

    Invoke-Command -Session $Session -ScriptBlock {
        $Using:FunctionsInvoked | ForEach-Object { Invoke-Expression "function $( $_.Name ) { $( $_.Body ) }" }
    }

    try {
        $Output = Invoke-Command -Session $Session -ScriptBlock $ScriptBlock
    }
    finally {
        Invoke-Command -Session $Session -ScriptBlock {
            $Using:FunctionsInvoked | ForEach-Object { Remove-Item -Path "Function:$( $_.Name )" }
        }
    }

    if ($CaptureOutput) {
        return $Output
    }
    else {
        Write-Host $Output
    }
}
