class CleanupStack {
    [System.Collections.Stack] $Stack = [System.Collections.Stack]::new()
    [ContrailRepo] $ContrailRepo = $null

    [Void] Push([ScriptBlock] $ScriptBlock, [PSobject[]] $Arguments) {
        $this.Stack.Push([FunctionObject]::new($ScriptBlock, $Arguments))
    }

    [Void] Push([BaseResourceModel] $ModelObject) {
        $this.Stack.Push($ModelObject)
    }

    [PSobject] Pop() {
        return $this.Stack.Pop()
    }

    [PSobject] Peek() {
        return $this.Stack.Peek()
    }

    [Void] RunCleanup([ContrailRepo] $ContrailRepo) {
        $this.ContrailRepo = $ContrailRepo
        while ($this.Stack.Count -ne 0) {
            $RemoveObject = $this.Stack.Pop()
            try {
                $this.Remove($RemoveObject)
            }
            catch {
                Write-Log (Out-String -InputObject $_)
            }
        }
    }

    [Void] Remove([FunctionObject] $FunctionObject) {
        Invoke-Command -ScriptBlock $FunctionObject.ScriptBlock -ArgumentList $FunctionObject.Arguments
    }

    [Void] Remove([BaseResourceModel] $ResourceModel) {
        $this.ContrailRepo.RemoveWithDependencies($ResourceModel) | Out-Null
    }
}
