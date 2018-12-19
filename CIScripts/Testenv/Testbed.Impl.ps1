class Testbed {
    [string] $Name
    [string] $VMName
    [string] $Address
    [string] $Username
    [string] $Password

    [PSSessionT[]] $Sessions = @()

    [PSSessionT] NewSession() {
        return $this.NewSession(10, 300000)
    }

    [PSSessionT] NewSession([Int] $RetryCount, [Int] $Timeout) {
        $Creds = $this.GetCredentials()
        $Session = if ($this.Address) {
            $pso = New-PSSessionOption -MaxConnectionRetryCount $RetryCount -OperationTimeout $Timeout
            New-PSSession -ComputerName $this.Address -Credential $Creds -SessionOption $pso
        }
        elseif ($this.VMName) {
            New-PSSession -VMName $this.VMName -Credential $Creds
        }
        else {
            throw "You need to specify 'address' or 'vmName' for a testbed to create a session."
        }

        $this.InitializeSession($Session)
        $this.Sessions += $Session

        return $Session
    }

    [Void] RemoveAllSessions() {
        foreach ($Session in $this.Sessions) {
            Remove-PSSession $Session -ErrorAction Continue
        }
    }

    hidden [PSCredentialT] GetCredentials() {
        if (-not ($this.Username -or $this.Password)) {
            return Get-Credential # assume interactive mode
        }
        else {
            $VMUsername = Get-UsernameInWorkgroup -Username $this.Username
            $VMPassword = $this.Password | ConvertTo-SecureString -AsPlainText -Force
            return [PSCredentialT]::new($VMUsername, $VMPassword)
        }
    }

    hidden [Void] InitializeSession([PSSessionT] $Session) {
        Invoke-Command -Session $Session -ScriptBlock {
            Set-StrictMode -Version Latest
            $ErrorActionPreference = "Stop"

            # Refresh PATH
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
                "", Justification = "We refresh PATH on remote machine, we don't use it here.")]
            $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        }
    }
}

function New-RemoteSessions {
    Param ([Parameter(Mandatory = $true)] [Testbed[]] $VMs)

    $Sessions = [System.Collections.ArrayList] @()
    foreach ($VM in $VMs) {
        $Sessions += $VM.NewSession()
    }
    return $Sessions
}

function Get-ComputeLogsDir { "C:/ProgramData/Contrail/var/log/contrail" }
