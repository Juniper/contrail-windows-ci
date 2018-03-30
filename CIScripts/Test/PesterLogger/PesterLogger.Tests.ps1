﻿$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "PesterLogger" {
    Context "Initialize-PesterLogger" {
        It "registers a new global Write-Log function" {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            Get-Item function:Write-Log -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "unregisters previous Write-Log function and registers a new one" {
            function OldImpl {}
            Mock OldImpl {}
            New-Item function:Write-Log -Value OldImpl
            Write-Log "test"

            Initialize-PesterLogger -OutDir "TestDrive:\"
            Get-Item function:Write-Log -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            Write-Log "test2"
            Assert-MockCalled OldImpl -Exactly -Times 1
        }
    }

    Context "Write-Log" {
        It "writes to correct file" {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            Write-Log "msg"
            Test-Path "TestDrive:\PesterLogger\Write-Log\writes to correct file.log" | Should -Be $true
        }

        It "changing location doesn't change the output directory" {
            Push-Location TestDrive:\
            Initialize-PesterLogger -OutDir "."

            New-Item -ItemType directory TestDrive:\abcd
            Push-Location TestDrive:\abcd

            Write-Log "msg"
            
            Pop-Location
            Pop-Location
            "TestDrive:\PesterLogger\Write-Log\changing location doesn't change the output directory.log" `
                | Should -Exist
        }

        It "writes correct messages" {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            Write-Log "msg1"
            Write-Log "msg2"
            Get-Content -Raw "TestDrive:\PesterLogger\Write-Log\writes correct messages.log" | Should -Be @"
msg1
msg2

"@
        }
    }

    Context "Initializing in BeforeEach" {
        It "registers Write-Log correctly" {
            Write-Log "hi"
            Get-Content -Raw "TestDrive:\PesterLogger\Initializing in BeforeEach\registers Write-Log correctly.log" `
                | Should -Be @"
hi

"@
        }
        BeforeEach {
            Initialize-PesterLogger -OutDir "TestDrive:\"
        }
    }

    AfterEach {
        if (Get-Item function:Write-Log -ErrorAction SilentlyContinue) {
            Remove-Item function:Write-Log
        }
    }
}
