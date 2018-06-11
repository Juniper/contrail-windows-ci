. $PSScriptRoot\..\..\Common\Init.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

. $PSScriptRoot/../../Common/Invoke-CommandInLocation.ps1

Describe "PesterLogger" -Tags CI, Unit {
    Context "Initialize-PesterLogger" {
        It "registers a new global Write-LogImpl function" {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            Get-Item function:Write-LogImpl -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "unregisters previous Write-LogImpl function and registers a new one" {
            function OldImpl {}
            Mock OldImpl {}
            New-Item function:Write-LogImpl -Value OldImpl
            Write-Log "test"

            Initialize-PesterLogger -OutDir "TestDrive:\"
            Get-Item function:Write-LogImpl -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            Write-Log "test2"
            Assert-MockCalled OldImpl -Exactly -Times 1
        }

        It "creates output directory if it doesn't exist" {
            Initialize-PesterLogger -OutDir "TestDrive:\some_dir"
            "TestDrive:\some_dir" | Should -Exist
        }

    }

    Context "Write-Log" {
        It "writes to correct file" {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            Write-Log "msg"
            Test-Path "TestDrive:\PesterLogger.Write-Log.writes to correct file.log" | Should -Be $true
        }

        It "changing location doesn't change the output directory" {
            Invoke-CommandInLocation TestDrive:\ {
                Initialize-PesterLogger -OutDir "."
    
                New-Item -ItemType directory TestDrive:\abcd

                Invoke-CommandInLocation TestDrive:\abcd {
                    Write-Log "msg"
                }
            }
            "TestDrive:\PesterLogger.Write-Log.changing location doesn't change the output directory.log" `
                | Should -Exist
        }

        It "writes correct messages" {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            Write-Log "msg1"
            Write-Log "msg2"
            Get-Content "TestDrive:\PesterLogger.Write-Log.writes correct messages.log" | Should -Be @("msg1", "msg2")
        }

        It "errors if test name contains : " {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            { Write-Log "msg1" } | Should -Throw
        }

        It "errors if test name contains / " {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            { Write-Log "msg1" } | Should -Throw
        }
    }

    Context "Initializing in BeforeEach" {
        It "registers Write-Log correctly" {
            Write-Log "hi"
            Get-Content "TestDrive:\PesterLogger.Initializing in BeforeEach.registers Write-Log correctly.log" `
                | Should -Be @("hi")
        }
        BeforeEach {
            Initialize-PesterLogger -OutDir "TestDrive:\"
        }
    }

    AfterEach {
        if (Get-Item function:Write-LogImpl -ErrorAction SilentlyContinue) {
            Remove-Item function:Write-LogImpl
        }
    }
}
