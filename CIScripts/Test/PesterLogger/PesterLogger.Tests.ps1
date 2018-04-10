$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

. $PSScriptRoot/../../Common/Invoke-CommandInLocation.ps1

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
    }

    Context "Move-Logs" {
        It "appends collected logs to correct output file" {
            Initialize-PesterLogger -OutDir "TestDrive:\" -Sessions @($Sess1)
            Write-Log "first message"
            Move-Logs -From $SourcePath
            $Content = Get-Content "TestDrive:\PesterLogger.Move-Logs.appends collected logs to correct output file.log"
            "first message" | Should -BeIn $Content
            "remote log text" | Should -BeIn $Content
        }

        It "cleans logs in source directory" {
            Initialize-PesterLogger -OutDir "TestDrive:\" -Sessions @($Sess1)
            Move-Logs -From $SourcePath
            Test-Path $SourcePath | Should -Be $false
        }

        It "doesn't clean logs in source directory if DontCleanUp flag passed" {
            Initialize-PesterLogger -OutDir "TestDrive:\" -Sessions @($Sess1)
            Move-Logs -From $SourcePath -DontCleanUp
            Test-Path $SourcePath | Should -Be $true
        }

        It "adds a prefix describing source directory" {
            Initialize-PesterLogger -OutDir "TestDrive:\" -Sessions @($Sess1)
            Write-Log "first message"
            Move-Logs -From $SourcePath
            $ContentRaw = Get-Content -Raw "TestDrive:\PesterLogger.Move-Logs.adds a prefix describing source directory.log"
            $ContentRaw | Should -BeLike "*$SourcePath*"
            $ComputerName = $Sess1.ComputerName
            $ContentRaw | Should -BeLike "*$ComputerName*"
        }
    
        It "works with multiple lines in remote logs" {
            "second line" | Add-Content "TestDrive:\remote.log"
            "third line" | Add-Content "TestDrive:\remote.log"
            Initialize-PesterLogger -OutDir "TestDrive:\" -Sessions @($Sess1)
            Move-Logs -From $SourcePath -DontCleanUp
            $ContentRaw = Get-Content -Raw "TestDrive:\PesterLogger.Move-Logs.works with multiple lines in remote logs.log"
            $ContentRaw | Should -BeLike "*remote log text*second line*third line*"
        }

        It "works with multiple sessions" {
            Initialize-PesterLogger -OutDir "TestDrive:\" -Sessions @($Sess1, $Sess2)
            Write-Log "first message"
            Move-Logs -From $SourcePath -DontCleanUp
            $ContentRaw = Get-Content -Raw "TestDrive:\PesterLogger.Move-Logs.works with multiple sessions.log"
            $ContentRaw | Should -BeLike "first message*$SourcePath*$SourcePath*"
            $ContentRaw | Should -BeLike "*remote log text*remote log text*"
            $ComputerName1 = $Sess1.ComputerName
            $ComputerName2 = $Sess2.ComputerName
            $ContentRaw | Should -BeLike "*$ComputerName1*$ComputerName2*"
            # Write-Host ($ContentRaw) would yield:
            # hihi
            # -----------------------------------------------------------------------------------------------------
            # Logs from localhost:C:\Users\mk\AppData\Local\Temp\aa0795ea-db6b-43d7-b1f4-d41adc8bf807\remote.log :
            # remote log text
            # -----------------------------------------------------------------------------------------------------
            # Logs from 127.0.0.1:C:\Users\mk\AppData\Local\Temp\aa0795ea-db6b-43d7-b1f4-d41adc8bf807\remote.log :
            # remote log text
        }

        BeforeEach {
            "remote log text" | Out-File "TestDrive:\remote.log"
            [
                Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
                "SourcePath",
                Justification="PSAnalyzer doesn't understand relations of Pester's blocks.")
            ]
            $SourcePath = ((Get-Item $TestDrive).FullName) + "\remote.log"
        }

        BeforeAll {
            $Sess1 = New-PSSession -ComputerName localhost
            $Sess2 = New-PSSession -ComputerName "127.0.0.1"
        }

        AfterAll {
            Remove-PSSession $Sess1
            Remove-PSSession $Sess2
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
        if (Get-Item function:Write-Log -ErrorAction SilentlyContinue) {
            Remove-Item function:Write-Log
        }
    }
}
