Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs"
)

. $PSScriptRoot\TestConfigurationUtils.ps1
. $PSScriptRoot\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\Testenv\Testbed.ps1
. $PSScriptRoot\PesterLogger\PesterLogger.ps1

Describe "New-Container" {
    It "Reports container id when container creation succeeds in first attempt" {
        Invoke-Command -Session $Session {
            $DockerThatAlwaysSucceeds = @"
            Write-Output "{0}"
            exit 0
"@ -f $Using:ContainerID
            Set-Content -Path "docker.ps1" -Value $DockerThatAlwaysSucceeds
        }

        $NewContainerID = New-Container `
            -Session $Session `
            -NetworkName "BestNetwork" `
            -Name "jolly-lumberjack" | Should -Not -Throw
        $NewContainerID | Should -Be $ContainerID
    }

    It "Throws exception when container creation fails" {
        Invoke-Command -Session $Session {
            $DockerThatAlwaysFails = @"
            Write-Error "It's Docker here: This is very very bad!"
            exit 1
"@
            Set-Content -Path "docker.ps1" -Value $DockerThatAlwaysFails
        }

        New-Container `
            -Session $Session `
            -NetworkName "NetworkOfFriends" `
            -Name "jolly-lumberjack" | Should -Throw
    }

    It "Reports container id when container creation succeeds in second attempt after failing because of known issue" {
        Invoke-Command -Session $Session {
            $DockerThatSucceedsInSecondAttempt = @'
            if ($args[0] -eq "run") {{
                $Hope = "HopeForSuccess"
                if (Test-Path $Hope) {{
                    Write-Output "{0}"
                    Remove-Item $Hope
                    exit 0
                }} else {{
                    Set-Content -Path $Hope -Value "New hope"
                    Write-Output "{0}"
                    Write-Error "It's Docker here: CreateContainer: failure in a Windows system call. Try again. Good luck!"
                    exit 1
                }}
            }} else {{
                Write-Output "{0}"
                exit 0
            }}
'@ -f $Using:ContainerID
            Set-Content -Path "docker.ps1" -Value $DockerThatSucceedsInSecondAttempt
        }

        $NewContainerID = New-Container `
            -Session $Session `
            -NetworkName "SoftwareDefinedNetwork" `
            -Name "jolly-lumberjack" | Should -Not -Throw
        $NewContainerID | Should -Be $ContainerID
    }

    It "Throws exception when container creation fails in first attempt and reports unknown issue" {
        Invoke-Command -Session $Session {
            $HopeStorage = "HopeForLuckyTry"
            Remove-Item $HopeStorage -ErrorAction Ignore
            $DockerThatSucceedsInSecondAttempt = @'
            if ($args[0] -eq "run") {{
                $Hope = "{1}"
                if (Test-Path $Hope) {{
                    Write-Output "{0}"
                    Remove-Item $Hope
                    exit 0
                }} else {{
                    Set-Content -Path $Hope -Value "There's actually no hope."
                    Write-Output "{0}"
                    Write-Error "It's Docker here: Error code #190583. Shall you try again?"
                    exit 1
                }}
            }} else {{
                Write-Output "{0}"
                exit 0
            }}
'@ -f $Using:ContainerID,$HopeStorage
            Set-Content -Path "docker.ps1" -Value $DockerThatSucceedsInSecondAttempt
        }

        $NewContainerID = New-Container `
            -Session $Session `
            -NetworkName "SoftwareDefinedNetwork" `
            -Name "jolly-lumberjack" | Should -Throw
    }

    BeforeAll {
        $Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "",
            Justification="Lifetime and visibility of variables is a matter beyond capabilities of code checker."
        )]
        $Session = $Sessions[0]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "",
            Justification="Lifetime and visibility of variables is a matter beyond capabilities of code checker."
        )]
        $ContainerID = "47f6baf1e42fa83b5ddb6a8dca9103178129ce454689f47ee59140dafc2c9a7c"
        Invoke-Command -Session $Session {
            $OldPath = $Env:Path
            $Env:Path = ".;$OldPath"
        }
    }

    AfterAll {
        Invoke-Command -Session $Session {
            Remove-Item docker.ps1
        }
    }
}
