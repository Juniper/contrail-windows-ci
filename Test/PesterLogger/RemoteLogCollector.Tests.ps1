Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\..\..\CIScripts\Common\Init.ps1
. $PSScriptRoot\..\..\CIScripts\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\CIScripts\Testenv\Testbed.ps1

. $PSScriptRoot\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\Utils\WinContainers\Containers.ps1
. $PSScriptRoot\PesterLogger.ps1
. $PSScriptRoot\Get-CurrentPesterScope.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

function Test-MultipleSourcesAndSessions {
    It "works with multiple log sources and sessions" {
        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1
        $Source2 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog2
        $Source3 = New-FileLogSource -Sessions $Sess2 -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"
        
        # We pass -DontCleanUp because in the tests, both sessions point at the same computer.
        Merge-Logs -DontCleanUp -LogSources @($Source1, $Source2, $Source3)
        
        $DescribeBlockName = (Get-CurrentPesterScope)[0]
        $ContentRaw = Get-Content -Raw "TestDrive:\$DescribeBlockName.works with multiple log sources and sessions.txt"
        $ContentRaw | Should -BeLike "*$DummyLog1*$DummyLog2*$DummyLog1*"
    }
}

$DummyLog1Basename = "remotelog"
$DummyLog2Basename = "remotelog_second"

Describe "RemoteLogCollector" -Tags CI, Unit {
    It "appends collected logs to correct output file" {
        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1
        "remote log text" | Add-Content $DummyLog1

        Initialize-PesterLogger -OutDir "TestDrive:\"
        Write-Log "first message"

        Merge-Logs -LogSources $Source1

        $Messages = Get-Content "TestDrive:\RemoteLogCollector.appends collected logs to correct output file.txt" |
            ConvertTo-LogItem | Foreach-Object Message
        "first message" | Should -BeIn $Messages
        "remote log text" | Should -BeIn $Messages
    }

    It "cleans logs in source directory" {
        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1
        "remote log text" | Add-Content $DummyLog1

        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $Source1

        Get-Content $DummyLog1 | Should -Be $null
    }

    It "doesn't clean logs in source directory if DontCleanUp flag passed" {
        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1
        "remote log text" | Add-Content $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -DontCleanUp -LogSources $Source1

        Get-Content $DummyLog1 | Should -Not -Be $null
    }

    It "tags the messages with file basename" {
        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1
        "remote log text" | Add-Content $DummyLog1

        Initialize-PesterLogger -OutDir "TestDrive:\"
        Write-Log "first message"

        Merge-Logs -LogSources $Source1

        Get-Content "TestDrive:\RemoteLogCollector.tags the messages with file basename.txt" |
            ConvertTo-LogItem | ForEach-Object Tag | Should -Contain $DummyLog1Basename
    }

    It "adds a prefix describing source directory" {
        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1
        "remote log text" | Add-Content $DummyLog1

        Initialize-PesterLogger -OutDir "TestDrive:\"
        Write-Log "first message"

        Merge-Logs -LogSources $Source1

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.adds a prefix describing source directory.txt"
        $ContentRaw | Should -BeLike "*$DummyLog1*"
        $ContentRaw | Should -BeLike "*localhost*"
    }

    It "works with multiple lines in remote logs" {
        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1

        "remote log text" | Add-Content $DummyLog1
        "second line" | Add-Content $DummyLog1
        "third line" | Add-Content $DummyLog1

        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $Source1

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.works with multiple lines in remote logs.txt"
        $ContentRaw | Should -BeLike "*remote log text*second line*third line*"
    }

    It "works when specifying a wildcard path" {
        $WildcardPath = ((Get-Item $TestDrive).FullName) + "\*.log"
        $WildcardSource = New-FileLogSource -Sessions $Sess1 -Path $WildcardPath

        "remote log text" | Add-Content $DummyLog1
        "another file content" | Add-Content $DummyLog2
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $WildcardSource

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.works when specifying a wildcard path.txt"
        $ContentRaw | Should -BeLike "*$DummyLog1*remote log*"
        $ContentRaw | Should -BeLike "*$DummyLog2*another file content*"
    }

    It "works with multiple sessions in single log source" {
        $Source2 = New-FileLogSource -Sessions @($Sess1, $Sess2) -Path $DummyLog1
        "remote log text" | Add-Content $DummyLog1

        Initialize-PesterLogger -OutDir "TestDrive:\"
        Write-Log "first message"

        # We pass -DontCleanUp because in the tests, both sessions point at the same computer.
        Merge-Logs -DontCleanUp -LogSources $Source2

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.works with multiple sessions in single log source.txt"
        $ContentRaw | Should -BeLike "*first message*$DummyLog1*$DummyLog1*"
        $ContentRaw | Should -BeLike "*remote log text*remote log text*"
        $ContentRaw | Should -BeLike "*localhost*localhost*"
    }

    It "works with multiple log sources" {
        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1
        $Source2 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog2

        "remote log text" | Add-Content $DummyLog1
        "another file content" | Add-Content $DummyLog2
        Initialize-PesterLogger -OutDir "TestDrive:\"

        # We pass -DontCleanUp because in the tests, both sessions point at the same computer.
        Merge-Logs -DontCleanUp -LogSources @($Source1, $Source2)

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.works with multiple log sources.txt"
        $ContentRaw | Should -BeLike "*$DummyLog1*$DummyLog2*"
        $ContentRaw | Should -BeLike "*remote log text*another file content*"
    }

    It "inserts warning message if filepath was not found" {
        Remove-Item $DummyLog1
        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $Source1

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.inserts warning message if filepath was not found.txt"
        $ContentRaw | Should -BeLike "*$DummyLog1*<FILE NOT FOUND>*"
    }

    It "inserts warning message if wildcard matched nothing" {
        Remove-Item $DummyLog1
        Remove-Item $DummyLog2
        $WildcardPath = ((Get-Item $TestDrive).FullName) + "\*.log"
        $WildcardSource = New-FileLogSource -Sessions $Sess1 -Path $WildcardPath
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $WildcardSource

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.inserts warning message if wildcard matched nothing.txt"
        $ContentRaw | Should -BeLike "*$WildcardPath*<FILE NOT FOUND>*"
    }

    It "inserts a message if log file was empty" {
        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $Source1

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.inserts a message if log file was empty.txt"
        $ContentRaw | Should -BeLike "*$DummyLog1*<EMPTY>*"
    }

    It "doesn't show messages from before initialization" {
        "remote log text" | Add-Content $DummyLog1

        $Source1 = New-FileLogSource -Sessions $Sess1 -Path $DummyLog1

        "new line" | Add-Content $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $Source1

        $Messages = Get-Content "TestDrive:\RemoteLogCollector.doesn't show messages from before initialization.txt" |
            ConvertTo-LogItem | Foreach-Object Message
        "first message" | Should -Not -BeIn $Messages
        "new line" | Should -BeIn $Messages
    }

    Test-MultipleSourcesAndSessions

    BeforeEach {
        $DummyLog1 = Join-Path ((Get-Item $TestDrive).FullName) ($DummyLog1Basename + ".log")
        $DummyLog2 = Join-Path ((Get-Item $TestDrive).FullName) ($DummyLog2Basename + ".log")

        New-Item $DummyLog1 -ItemType File
        New-Item $DummyLog2 -ItemType File
    }


    AfterEach {
        Remove-Item "TestDrive:/*" 
        if (Get-Item function:Write-LogImpl -ErrorAction SilentlyContinue) {
            Remove-Item function:Write-LogImpl
        }
    }

    BeforeAll {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "Sess1", Justification="Pester blocks are handled incorrectly by analyzer.")]
        $Sess1 = $null
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "Sess2", Justification="Pester blocks are handled incorrectly by analyzer.")]
        $Sess2 = $null
    }
}

Describe "RemoteLogCollector - with actual Testbeds" -Tags CI, Systest {

    BeforeAll {
        $Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "Sess1", Justification="Pester blocks are handled incorrectly by analyzer.")]
        $Sess1 = $Sessions[0]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "Sess2", Justification="Pester blocks are handled incorrectly by analyzer.")]
        $Sess2 = $Sessions[1]
    }

    AfterAll {
        if (-not (Get-Variable Sessions -ErrorAction SilentlyContinue)) { return }
        Remove-PSSession $Sessions
    }

    BeforeEach {
        $DummyLog1 = Join-Path ((Get-Item $TestDrive).FullName) ($DummyLog1Basename + ".log")
        "remote log text" | Out-File $DummyLog1

        $DummyLog2 = Join-Path ((Get-Item $TestDrive).FullName) ($DummyLog2Basename + ".log")
        "another file content" | Out-File $DummyLog2
    }

    AfterEach {
        Remove-Item "TestDrive:/*" 
        if (Get-Item function:Write-LogImpl -ErrorAction SilentlyContinue) {
            Remove-Item function:Write-LogImpl
        }
    }

    Test-MultipleSourcesAndSessions

    Context "Container logs" {
        BeforeEach {
            Initialize-PesterLogger -OutDir "TestDrive:\"
        }

        It "captures logs of container" {
            New-Container -Session $Sess1 -Name foo -Network nat

            Merge-Logs (New-ContainerLogSource -Sessions $Sess1 -ContainerNames foo)
            $ContentRaw = Get-Content -Raw "TestDrive:\*.Container logs.captures logs of container.txt"
            $ContentRaw | Should -BeLike "*Microsoft Windows*"
        }

        It "handles nonexisting container" {
            Merge-Logs (New-ContainerLogSource -Sessions $Sess1 -ContainerNames bar)
            # Should not throw.
            # We're not using actual `Should -Not -Throw` here,
            # because it doesn't show exception's location in case of failure.
        }

        AfterEach {
            Remove-AllContainers -Session $Sess1
        }
    }

    Context "Windows Eventlog" {
        BeforeEach {
            Invoke-Command -Session $Sess1 {
                New-EventLog -Source "Test" -LogName "TestLog"
            }
        }
        AfterEach {
            Invoke-Command -Session $Sess1 {
                Remove-EventLog -LogName "TestLog"
            }
        }
        It "reading from non-existing log collector returns proper error in logs" {
            $Source = New-EventLogLogSource -Sessions $Sess1 -EventLogName "Invalid Name" -EventLogSource "Invalid source"
            Initialize-PesterLogger -OutDir "TestDrive:\"

            Merge-Logs -LogSources $Source

            $ContentRaw = Get-Content -Raw "TestDrive:\*.Windows Eventlog.reading from non-existing log collector returns proper error in logs.txt"
            $ContentRaw | Should -BeLike "*event log retrieval error:*"
        }
        It "getting logs from event log works" {
            $Source = New-EventLogLogSource -Sessions $Sess1 -EventLogName "TestLog" -EventLogSource "Test"
            Initialize-PesterLogger -OutDir "TestDrive:\"

            Invoke-Command -Session $Sess1 {
                Write-EventLog -LogName "TestLog" -Source "Test" -EntryType Information -Message "first entry" -ID 1
            }
            Merge-Logs -LogSources $Source

            $ContentRaw = Get-Content -Raw "TestDrive:\*.Windows Eventlog.getting logs from event log works.txt"
            $ContentRaw | Should -BeLike "*first entry*"
        }
        It "ignores messages from before initialization" {
            Invoke-Command -Session $Sess1 {
                Write-EventLog -LogName "TestLog" -Source "Test" -EntryType Information -Message "entry before initialization" -ID 1
            }
            $Source = New-EventLogLogSource -Sessions $Sess1 -EventLogName "TestLog" -EventLogSource "Test"
            Initialize-PesterLogger -OutDir "TestDrive:\"

            Invoke-Command -Session $Sess1 {
                Write-EventLog -LogName "TestLog" -Source "Test" -EntryType Information -Message "first entry" -ID 1
            }
            Merge-Logs -LogSources $Source

            $ContentRaw = Get-Content -Raw "TestDrive:\*.Windows Eventlog.ignores messages from before initialization.txt"
            $ContentRaw | Should -Not -BeLike "*entry before initialization*"
            $ContentRaw | Should -BeLike "*first entry*"
        }
        It "ignores messages from before clearing content" {
            $Source = New-EventLogLogSource -Sessions $Sess1 -EventLogName "TestLog" -EventLogSource "Test"
            Initialize-PesterLogger -OutDir "TestDrive:\"
            Invoke-Command -Session $Sess1 {
                Write-EventLog -LogName "TestLog" -Source "Test" -EntryType Information -Message "entry before clearing" -ID 1
            }

            $Source.ClearContent()
            Invoke-Command -Session $Sess1 {
                Write-EventLog -LogName "TestLog" -Source "Test" -EntryType Information -Message "first entry" -ID 1
            }
            Merge-Logs -LogSources $Source

            $ContentRaw = Get-Content -Raw "TestDrive:\*.Windows Eventlog.ignores messages from before clearing content.txt"
            $ContentRaw | Should -Not -BeLike "*entry before clearing*"
            $ContentRaw | Should -BeLike "*first entry*"
        }
        It "doesn't read previous entries if nothing was added to event log" {
            # Regression test for a case pointed by Magdalena during code review.
            Invoke-Command -Session $Sess1 {
                Write-EventLog -LogName "TestLog" -Source "Test" -EntryType Information -Message "previous entry" -ID 1
            }
            $Source = New-EventLogLogSource -Sessions $Sess1 -EventLogName "TestLog" -EventLogSource "Test"
            Initialize-PesterLogger -OutDir "TestDrive:\"

            Merge-Logs -LogSources $Source

            $ContentRaw = Get-Content -Raw "TestDrive:\*.Windows Eventlog.doesn't read previous entries if nothing was added to event log.txt"
            $ContentRaw | Should -Not -BeLike "*previous entry*"
            $ContentRaw | Should -BeLike "*EMPTY*"
        }
    }
}
