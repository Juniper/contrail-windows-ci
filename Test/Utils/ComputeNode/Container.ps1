. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Invoke-CommandWithFunctions.ps1

function Format-Arguments {
    Param (
        [Parameter(Mandatory = $true)] [PSCustomObject] $Arguments
    )

    $FArguments = `
         $Arguments.GetEnumerator() `
            | ForEach-Object { "-$($_.Key) '$($_.Value)'" } `

    return $FArguments -join " "
}

function Evaluate-Arguments {
    Param (
        [Parameter(Mandatory = $true)] [string] $Arguments
    )
    $Regex = "(\$[a-zA-Z0-9]+)"

    $Arguments = $Arguments -replace "'$Regex'", '$1'
    $ArgsToEvaluate = [regex]::Matches($Arguments, $Regex)
    $EvaluatedArgs = $Arguments

    $IndexCorrection = 0
    foreach ($ArgToEvaluate in $ArgsToEvaluate) {
        $IndexOfVariable = $ArgToEvaluate.Index + $IndexCorrection

        $EvaluatedArg = "'$(iex $ArgToEvaluate.Value)'"

        $EvaluatedArgs = $EvaluatedArgs.Remove($IndexOfVariable, $ArgToEvaluate.Length)
        $EvaluatedArgs = $EvaluatedArgs.Insert($IndexOfVariable, $EvaluatedArg)

        $IndexCorrection = $IndexCorrection + $EvaluatedArg.Length - $ArgToEvaluate.Length
    }

    return $EvaluatedArgs
}

function Format-FlatFunction {
    Param (
        [Parameter(Mandatory = $true)] [string] $Function
    )

    $FunctionBody = $(Get-Content function:$Function).ToString()

    $FlatFunctionBody = $($($($($(
        $FunctionBody `
            -replace "(^|``|$)(`r`n|`n)", '') `
            -replace "\}(`r`n|`n)\s*(catch|else if|else|finally)", '} $2') `
            -replace "(`r`n|`n)\s*(\))", '$2') `
            -replace "(\(|,|\{)\s*(`r`n|`n)", '$1') `
            -replace "(`r`n|`n)", ";") `
            -replace "\s+", ' '

    # $InBytes = [System.Text.Encoding]::Unicode.GetBytes($FunctionBody)
    # $Encoded = [Convert]::ToBase64String($FunctionBody)

    #return "[System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($Encoded)"
    return $FlatFunctionBody
}

function Format-Command {
    Param (
        [Parameter(Mandatory = $true)] [string] $Function,
        [Parameter(Mandatory = $true)] [string] $FBody,
        [Parameter(Mandatory = $true)] [string] $FArguments
    )

    return "function $Function { $FBody } $Function $FArguments"
}

function Get-DockerExec {
    return "docker exec"
}

function Format-DockerExec {
    Param (
        [Parameter(Mandatory = $true)] [string] $ContainerName,
        [Parameter(Mandatory = $false)] [string] $Shell = "powershell"
    )

    $Arguments = Evaluate-Arguments -Arguments $global:FunctionToInvokeDockerExecWith.Arguments
    $Command = Format-Command `
                    -Function $global:FunctionToInvokeDockerExecWith.Name `
                    -FBody $global:FunctionToInvokeDockerExecWith.Body `
                    -FArguments $Arguments

    return "$(Get-DockerExec) $ContainerName $Shell 'invoke-command { $Command }'"
}

function Invoke-DockerExec {
    Param (
        [Parameter(Mandatory = $true)] [string] $ContainerName,
        [Parameter(Mandatory = $false)] [string] $Shell = "powershell"
    )

    Invoke-Expression $(Format-DockerExec @PSBoundParameters)
}

function Edit-ScriptBlock {
    Param (
        [Parameter(Mandatory = $true)] [string] $Function,
        [Parameter(Mandatory = $true)] [PSCustomObject] $Arguments,
        [Parameter(Mandatory = $true)] [ScriptBlock] $ScriptBlock
    )

    $FArguments = Format-Arguments -Arguments $Arguments
    $FunctionBody = Format-FlatFunction -Function $Function

    $InitScriptBlock = {
        $FDetails = @'
Name = {0}
Body = {1}
Arguments = {2}
'@
        $global:FunctionToInvokeDockerExecWith = ConvertFrom-StringData $FDetails
    } -f $Function, $FunctionBody, $FArguments

    return [scriptblock]::Create($InitScriptBlock + $ScriptBlock.ToString())
}

function Invoke-FunctionInContainer {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [string] $Function,
        [Parameter(Mandatory = $true)] [string] $ContainerName,
        [Parameter(Mandatory = $true)] [PSCustomObject] $Arguments,
        [Parameter(Mandatory = $true)] [ScriptBlock] $ScriptBlock
    )

    $Functions = @("Evaluate-Arguments", "Get-DockerExec", "Format-Command", "Format-DockerExec", "Invoke-DockerExec")

    $PreparedScriptBlock = Edit-ScriptBlock -Function $Function -Arguments $Arguments -ScriptBlock $ScriptBlock

    Invoke-CommandWithFunctions `
        -Functions $Functions `
        -Session $Session `
        -ScriptBlock $PreparedScriptBlock
}
