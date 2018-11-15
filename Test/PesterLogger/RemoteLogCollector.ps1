. $PSScriptRoot\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\CIScripts\Common\Invoke-NativeCommand.ps1

. $PSScriptRoot\PesterLogger.ps1

class CollectedLog {
    [String] $Name
}

class ValidCollectedLog : CollectedLog {
    [String] $Name
    [String] $Tag
    [Object] $Content
}

class InvalidCollectedLog : CollectedLog {
    [Object] $Err
}

class LogSource {
    [System.Management.Automation.Runspaces.PSSession] $Session

    [CollectedLog[]] GetContent() {
        throw "LogSource is an abstract class, use specific log source instead"
    }

    ClearContent() {
        throw "LogSource is an abstract class, use specific log source instead"
    }
}

class FileLogSource : LogSource {
    [String] $Path

    [CollectedLog[]] GetContent() {
        $ContentGetterBody = {
            Param([Parameter(Mandatory = $true)] [string] $From)
            $Files = Get-ChildItem -Path $From -ErrorAction SilentlyContinue
            $Logs = @()
            if (-not $Files) {
                $Logs += @{
                    Name = $From
                    Err = "<FILE NOT FOUND>"
                }
            } else {
                foreach ($File in $Files) {
                    $Content = Get-Content -Raw $File
                    $Logs += @{
                        Name = $File
                        Tag = $File.BaseName
                        Content = $Content
                    }
                }
            }
            return $Logs
        }

        # We cannot create [ValidCollectedLog] and [InvalidCollectedLog] classes directly
        # in the closure, as it may be executed in remote session, so as a workaround
        # we need to fix the types afterwards.
        return Invoke-CommandRemoteOrLocal -Func $ContentGetterBody -Session $this.Session -Arguments $this.Path |
            ForEach-Object {
                if ($_['Err']) {
                    [InvalidCollectedLog] $_
                } else {
                    [ValidCollectedLog] $_
                }
            }
    }

    ClearContent() {
        $LogCleanerBody = {
            Param([Parameter(Mandatory = $true)] [string] $What)
            $Files = Get-ChildItem -Path $What -ErrorAction SilentlyContinue
            foreach ($File in $Files) {
                try {
                    Clear-Content $File -Force
                }
                catch {
                    Write-Warning "$File was not cleared due to $_"
                }
            }
        }
        Invoke-CommandRemoteOrLocal -Func $LogCleanerBody -Session $this.Session -Arguments $this.Path
    }
}

class EventLogLogSource : LogSource {
    [String] $EventLogName
    [String] $EventLogSource
    [int64] $StartEventIdx

    EventLogLogSource($Session, $EventLogName, $EventLogSource) {
        $This.Session = $Session
        $this.EventLogName = $EventLogName
        $this.EventLogSource = $EventLogSource
        $this.StartEventIdx = $this.GetLatestEventIdx()
    }

    [CollectedLog[]] GetContent() {
        $LogGetterBody = {
            Param([Parameter(Mandatory = $true)] [string] $LogName,
                  [Parameter(Mandatory = $true)] [string] $LogSource,
                  [Parameter(Mandatory = $true)] [int64] $StartEventIdx,
                  [Parameter(Mandatory = $true)] [int64] $EndEventIdx)

            $Content = Get-EventLog `
                -LogName $LogName `
                -Source $LogSource `
                -Index ($StartEventIdx..$EndEventIdx) | Out-String

            $Name = "$LogSource - $LogName"
            return @{
                Name = "EventLog from $Name"
                Tag = "$Name"
                Content = $Content
            }
        }

        $Start = $this.StartEventIdx
        $End = $this.GetLatestEventIdx()

        return Invoke-CommandRemoteOrLocal -Func $LogGetterBody -Session $this.Session `
                -Arguments @($this.EventLogName, $this.EventLogSource, $Start, $End) |
            ForEach-Object {
                if ($_['Err']) {
                    [InvalidCollectedLog] $_
                } else {
                    [ValidCollectedLog] $_
                }
            }
    }

    ClearContent() {
        $this.StartEventIdx = $this.GetLatestEventIdx()
    }

    [int64] GetLatestEventIdx() {
        $Getter = {
            Param([Parameter(Mandatory = $true)] [string] $LogName,
                  [Parameter(Mandatory = $true)] [string] $LogSource)
            try {
                return Get-EventLog -LogName $LogName -Source $LogSource -Newest 1 | Select-Object -Expand Index
            } catch [System.ArgumentException] {
                # This may happen if we instantiate EventLogLogCollector before the corresponding EventLog exist.
                # In such case, the EventLog should start numbering from 1 anyways, so just return 1.
                return 1
            }
        }
        return Invoke-CommandRemoteOrLocal -Func $Getter -Session $this.Session `
            -Arguments @($this.EventLogName, $this.EventLogSource)
    }
}


class ContainerLogSource : LogSource {
    [String] $Container

    [CollectedLog[]] GetContent() {
        $Command = Invoke-NativeCommand -Session $this.Session -CaptureOutput -AllowNonZero {
            docker logs $Using:this.Container
        }
        $Name = "$( $this.Container ) container logs"

        $Log = if ($Command.ExitCode -eq 0) {
            [ValidCollectedLog] @{
                Name = $Name
                Tag = $this.Container
                Content = $Command.Output
            }
        } else {
            [InvalidCollectedLog] @{
                Name = $Name
                Err = $Command.Output
            }
        }
        return $Log
    }

    ClearContent() {
        # It's not possible to clear docker container logs, but it's OK because we have fresh
        # containers in each test case.
        # If we really need to cleanup though, we could use --since flag in GetContent.
    }
}

function New-ContainerLogSource {
    Param([Parameter(Mandatory = $true)] [string[]] $ContainerNames,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

    return $Sessions | ForEach-Object {
        $Session = $_
        $ContainerNames | ForEach-Object {
            [ContainerLogSource] @{
                Session = $Session
                Container = $_
            }
        }
    }
}

function New-FileLogSource {
    Param([Parameter(Mandatory = $true)] [string] $Path,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

    return $Sessions | ForEach-Object {
        [FileLogSource] @{
            Session = $_
            Path = $Path
        }
    }
}

function New-EventLogLogSource {
    Param([Parameter(Mandatory = $true)] [string] $EventLogName,
          [Parameter(Mandatory = $true)] [string] $EventLogSource,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

    return $Sessions | ForEach-Object {
        [EventLogLogSource]::new($_, $EventLogName, $EventLogSource)
    }
}

function Invoke-CommandRemoteOrLocal {
    param([ScriptBlock] $Func, [PSSessionT] $Session, [Object[]] $Arguments) 
    if ($Session) {
        Invoke-Command -Session $Session $Func -ArgumentList $Arguments
    } else {
        Invoke-Command $Func -ArgumentList $Arguments
    }
}

function Merge-Logs {
    Param([Parameter(Mandatory = $true)] [LogSource[]] $LogSources,
          [Parameter(Mandatory = $false)] [switch] $DontCleanUp)

    foreach ($LogSource in $LogSources) {
        $SourceHost = if ($LogSource.Session) {
            $LogSource.Session.ComputerName
        } else {
            "localhost"
        }
        $ComputerNamePrefix = "Logs from $($SourceHost): "
        Write-Log ("=" * 100)
        Write-Log $ComputerNamePrefix

        foreach ($Log in $LogSource.GetContent()) {
            if ($Log -is [ValidCollectedLog]) {
                Write-Log ("-" * 100)
                Write-Log "Contents of $( $Log.Name ):"
                if ($Log.Content) {
                    Write-Log -NoTimestamp -Tag $Log.Tag $Log.Content
                } else {
                    Write-Log "<EMPTY>"
                }
            } else {
                Write-Log "Error retrieving $( $Log.Name ):"
                Write-Log $Log.Err
            }
        }
        
        if (-not $DontCleanUp) {
            $LogSource.ClearContent()
        }
    }

    Write-Log ("=" * 100)
}

function Clear-Logs {
    Param([Parameter(Mandatory = $true)] [LogSource[]] $LogSources)
    foreach ($LogSource in $LogSources) {
        $LogSource.ClearContent()
    }
}
