Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot/Invoke-CommandWithFunctions.ps1
. $PSScriptRoot/Init.ps1
. $PSScriptRoot/../Testenv/Testenv.ps1
. $PSScriptRoot/../Testenv/Testbed.ps1

Describe "Invoke-CommandWithFunctions tests" -Tags CI {
    function Test-CWF {
        param(
            [Parameter(Mandatory=$true)] [PSCustomObject] $FunctionsInvoked,
            [Parameter(Mandatory=$true)] [ScriptBlock] $ScriptBlock,
            [Switch] $CaptureOutput
        )

        Invoke-CommandWithFunctions -Session $Session `
            -FunctionsInvoked $FunctionsInvoked `
            -ScriptBlock $ScriptBlock `
            -CaptureOutput:$CaptureOutput
    }

    function Test-SimpleFunction {
        param(
            [Parameter(Mandatory=$false)] [string] $SimpleParam = "A simple string to return"
        )

        return $SimpleParam
    }

    $TestSimpleFunctionInvoked = @(
        @{ Name = "Test-SimpleFunction";
           Body = ${Function:Test-SimpleFunction} } )

    Context "Incorrect function usage handling" {
        It "throws on nonexisting function" {
            { Test-CWF -FunctionsInvoked $TestSimpleFunctionInvoked  `
              -ScriptBlock { Test-ANonExistingFunction } } | Should Throw
        }

        It "throws on invoking with incorrectly passed parameter" {
            { Test-CWF -FunctionsInvoked $TestSimpleFunctionInvoked  `
              -ScriptBlock { Test-SimpleFunction -InvalidParam $true } } | Should Throw
        }
    }

    Context "correctly defined simple functions" {
        It "invokes function passed in ScriptBlock" {
            $str = "A simple string"
            Test-CWF -FunctionsInvoked $TestSimpleFunctionInvoked  `
                -ScriptBlock { Test-SimpleFunction -SimpleParam $using:str } `
                -CaptureOutput | Should Be $str
        }

        It "correctly invokes function with parameters defined at remote session" {
            Test-CWF -FunctionsInvoked $TestSimpleFunctionInvoked  `
                -ScriptBlock { $a = "abcd"; Test-SimpleFunction -SimpleParam $a } `
                -CaptureOutput | Should Be "abcd"
        }
    }

    Context "function invoking another function" {
        function Test-OuterFunction {
            param(
                [Parameter(Mandatory=$true)] [string] $TestString,
                [Switch] $DoAThrow
            )
            [ScriptBlock]$Sb = [ScriptBlock]::Create( $TestString )
            Test-InnerFunction -ScriptBlock $Sb -ArgumentList $TestString -DoAThrow:$DoAThrow 
        }

        function Test-InnerFunction {
            param(
                [Parameter(Mandatory=$true)] [ScriptBlock] $ScriptBlock,
                [Parameter(Mandatory=$true)] [Object[]] $ArgumentList,
                [Switch] $DoAThrow
            )

            if ( $DoAThrow ) {
                throw "threw"
            }
            else {
                Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
            }
         }
    
        $TestFunctionsInvoked = @( 
            @{ Name = "Test-OuterFunction"; 
               Body = ${Function:Test-OuterFunction} },
            @{ Name = "Test-InnerFunction"; 
               Body = ${Function:Test-InnerFunction} } )

        It "Inner function calls passed string as scriptblock and outputs result" {
            Test-CWF -FunctionsInvoked $TestFunctionsInvoked  `
                -ScriptBlock { Test-OuterFunction -TestString "whoami.exe" } `
                -CaptureOutput | Should Not BeNullOrEmpty
        }

        It "allows to throw exception" {
            { Test-CWF -FunctionsInvoked $TestFunctionsInvoked  `
              -ScriptBlock { Test-OuterFunction -TestString "" -DoAThrow } } | Should Throw
        }

        It "works with pipelines" {
            function Test-PipelineFunction {
                param([Parameter(ValueFromPipeline=$true)] $notUsed)

                Process { Test-SimpleFunction -SimpleParam $_ }
            }

            $TestPipelineInvoked = $TestSimpleFunctionInvoked
            $TestPipelineInvoked += @{
                Name = "Test-PipelineFunction";
                Body = ${Function:Test-PipelineFunction} }

            Test-CWF -FunctionsInvoked $TestPipelineInvoked  `
                -ScriptBlock { 1..5 | Test-PipelineFunction } `
                -CaptureOutput | Should Be @('1', '2', '3', '4', '5')
        }
    }

    BeforeAll {
        $Testbed = (Read-TestbedsConfig -Path $TestenvConfFile)[0]
        $Sessions = New-RemoteSessions -VMs $Testbed
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "Session",
            Justification="Analyzer doesn't understand relation of Pester blocks"
        )]
        $Session = $Sessions[0]
    }
}
