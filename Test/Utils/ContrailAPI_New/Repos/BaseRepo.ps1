class BaseRepo {
    [String] $ResourceName

    [ContrailNetworkManager] $API

    BaseRepo([ContrailNetworkManager] $API) {
        $this.API = $API
    }

    # Override in derivered
    hidden [void] RemoveDependencies([BaseModel] $Object) {
    }

    # Override in derivered
    hidden [PSobject] GetAddRequest([BaseModel] $Object) {
        throw "Operation Add not permited on object: $($Object.GetType().Name)"
    }

    [String] Add([BaseModel] $Object) {

        $Request = $this.GetAddRequest($Object)

        $Response = $this.API.Post($this.ResourceName, $null, $Request)
        $Object.Uuid = $Response."$($this.ResourceName)".'uuid'
        return $Object.Uuid
    }

    [String] AddOrReplace([BaseModel] $Object) {
        try {
            return $this.Add($Object)
        }
        catch {
            if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
                throw
            }
        }
        $this.RemoveWithDependencies($Object)
        return $this.Add($Object)
    }

    Hidden [Void] RemoveObject([BaseModel] $Object, [bool] $WithDependencies) {
        if (-not $Object.Uuid) {
            $Object.Uuid = $this.API.FQNameToUuid($this.ResourceName, $Object.GetFQName())
        }

        if ($WithDependencies) {
            $this.RemoveDependencies($Object)
        }

        $this.API.Delete($this.ResourceName, $Object.Uuid, $null)
        $Object.Uuid = $null
    }

    [Void] RemoveWithDependencies([BaseModel] $Object) {
        $this.RemoveObject($Object, $true)
    }

    [Void] Remove([BaseModel] $Object) {
        $this.RemoveObject($Object, $false)
    }
}
