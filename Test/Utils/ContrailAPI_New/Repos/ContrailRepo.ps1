class ContrailRepo {
    [ContrailNetworkManager] $API

    ContrailRepo([ContrailNetworkManager] $API) {
        $this.API = $API
    }

    hidden [void] RemoveDependencies([BaseResourceModel] $Object) {
        if (-not $Object.Dependencies) {
            return
        }
        $Uuid = $this.API.FQNameToUuid($Object.ResourceName, $Object.GetFQName())
        $Response = $this.API.Get($Object.ResourceName, $Uuid, $null)
        $Props = $Response.$($Object.ResourceName).PSobject.Properties.Name

        ForEach ($Dependency in $Object.Dependencies) {
            if ($Props -contains $Dependency.ReferencesField) {
                ForEach ($Child in $Response.$($Object.ResourceName).$($Dependency.ReferencesField)) {
                    $this.API.Delete($Dependency.ResourceName, $Child.'uuid', $null)
                }
            }
        }
    }

    [PSobject] Add([BaseResourceModel] $Object) {
        $Request = $Object.GetRequest()
        $Request.$($Object.ResourceName) += @{
            parent_type = $Object.ParentType
            fq_name     = $Object.GetFQName()
        }

        $Response = $this.API.Post($Object.ResourceName, $null, $Request)
        return $Response
    }

    [PSobject] Set([BaseResourceModel] $Object) {
        $Uuid = $this.API.FQNameToUuid($Object.ResourceName, $Object.GetFQName())
        $Request = $Object.GetRequest()

        $Response = $this.API.Put($Object.ResourceName, $Uuid, $Request)
        return $Response
    }

    [PSobject] AddOrReplace([BaseResourceModel] $Object) {
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

    Hidden [Void] RemoveObject([BaseResourceModel] $Object, [bool] $WithDependencies) {
        $Uuid = $this.API.FQNameToUuid($Object.ResourceName, $Object.GetFQName())

        if ($WithDependencies) {
            $this.RemoveDependencies($Object)
        }

        $this.API.Delete($Object.ResourceName, $Uuid, $null) | Out-Null
    }

    [Void] RemoveWithDependencies([BaseResourceModel] $Object) {
        $this.RemoveObject($Object, $true)
    }

    [Void] Remove([BaseResourceModel] $Object) {
        $this.RemoveObject($Object, $false)
    }
}
