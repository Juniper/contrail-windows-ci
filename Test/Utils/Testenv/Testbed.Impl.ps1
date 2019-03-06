class Testbed {
    [string] $Name
    [string] $VMName
    [string] $Address
    [string] $Username
    [string] $Password
    [System.Collections.Hashtable] $VhostInfo

    hidden [string] $VhostName
    hidden [string] $WinVersion

    [PSSessionT] $Session = $null

    [PSSessionT] NewSession() {
        return $this.NewSession(10, 300000)
    }

    static [Testbed[]] LoadFromFile([string] $Path) {
        $Parsed = Read-TestenvFile($Path)
        return [Testbed[]] $Parsed.Testbeds
    }

    [PSSessionT] NewSession([Int] $RetryCount, [Int] $Timeout) {
        if ($null -ne $this.Session) {
            Remove-PSSession $this.Session -ErrorAction SilentlyContinue
        }

        $Creds = $this.GetCredentials()
        $this.Session = if ($this.Address) {
            $pso = New-PSSessionOption -MaxConnectionRetryCount $RetryCount -OperationTimeout $Timeout
            New-PSSession -ComputerName $this.Address -Credential $Creds -SessionOption $pso
        }
        elseif ($this.VMName) {
            New-PSSession -VMName $this.VMName -Credential $Creds
        }
        else {
            throw "You need to specify 'address' or 'vmName' for a testbed to create a session."
        }

        $this.InitializeSession($this.Session)

        return $this.Session
    }

    [Void] RemoveAllSessions() {
        Remove-PSSession $this.Session -ErrorAction Continue
        $this.Session = $null
    }


    [PSSessionT] GetSession() {
        if (($null -ne $this.Session) -and ('Opened' -ne $this.Session.State)) {
            Remove-PSSession $this.Session -ErrorAction SilentlyContinue
            $this.Session = $null
        }
        if ($null -eq $this.Session) {
            return $this.NewSession()
        }
        return $this.Session
    }

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText",
        "", Justification = "This are just credentials to a testbed VM.")]
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

    [string] GetVhostName() {
        if ($null -eq $this.VhostName) {
            $this.SetVhostName()
        }
        Write-host "$($this.Name) $($this.VhostName)"
        return $this.VhostName
    }

    [Void] SetVhostName() {
        switch -Wildcard ($this.GetWindowsVersion()) {
            "*2016*" {
                $this.VhostName = "vEthernet (HNSTransparent)"
            }
            default {
                throw "Not supported Windows version"
            }
        }
    }

    [Void] SaveVhostInfo() {
        $adapterName = $this.GetVhostName()
        $this.VhostInfo = Invoke-Command -Session $this.GetSession() -ScriptBlock {
            $ipInfo = Get-NetIPAddress -ErrorAction SilentlyContinue -AddressFamily "IPv4" -InterfaceAlias $Using:adapterName
            $adapterInfo = Get-NetAdapter -ErrorAction SilentlyContinue -IncludeHidden -Name $Using:adapterName | `
                Select-Object ifName, MacAddress, ifIndex

            return @{
                IfIndex = $adapterInfo.IfIndex;
                IfName = $adapterInfo.ifName;
                MACAddress = $adapterInfo.MacAddress.Replace("-", ":").ToLower();
                MACAddressWindows = $adapterInfo.MacAddress.ToLower();
                IPAddress = $ipInfo.IPAddress;
                PrefixLength = $ipInfo.PrefixLength;
            }
        }
        Write-host "$($this.Name) $($this.VhostInfo)"
    }

    [Void] SetWindowsVersion() {
        $this.WinVersion = Invoke-Command -Session $this.GetSession() -ScriptBlock {
            (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
        }
    }

    [string] GetWindowsVersion() {
        if ($null -eq $this.WinVersion) {
            $this.SetWindowsVersion()
        }
        Write-host "$($this.Name) $($this.WinVersion)"
        return $this.WinVersion
    }
}

class TestbedConverter : System.Management.Automation.PSTypeConverter {
    $ToTypes = @([PSSessionT])

    [Bool] CanConvertFrom([System.Object] $Source, [Type] $Destination) {
        return $false
    }
    [System.Object] ConvertFrom([System.Object] $Source, [Type] $Destination, [System.IFormatProvider] $Provider, [Bool] $IgnoreCase) {
        throw [System.InvalidCastException]::new();
    }

    [Bool] CanConvertTo([System.Object] $Source, [Type] $Destination) {
        if ($Destination -in $this.ToTypes) {
            return $true
        }
        return $false
    }
    [System.Object] ConvertTo([System.Object] $Source, [Type] $Destination, [System.IFormatProvider] $Provider, [Bool] $IgnoreCase) {
        if ($Destination.Equals([PSSessionT])) {
            return $this.ConvertToPSSession($Source)
        }
        throw [System.InvalidCastException]::new('Not implemented')
    }

    [PSSessionT] ConvertToPSSession([Testbed] $Testbed) {
        return $Testbed.GetSession()
    }
}

Update-TypeData -TypeName 'Testbed' -TypeConverter 'TestbedConverter' -ErrorAction SilentlyContinue

function New-RemoteSessions {
    Param ([Parameter(Mandatory = $true)] [Testbed[]] $VMs)

    $Sessions = [System.Collections.ArrayList] @()
    try {
        foreach ($VM in $VMs) {
            $Sessions += $VM.NewSession()
        }
    }
    catch {
        Remove-PSSession $Sessions
        throw
    }
    return $Sessions
}

function Get-ComputeLogsDir { "C:/ProgramData/Contrail/var/log/contrail" }
