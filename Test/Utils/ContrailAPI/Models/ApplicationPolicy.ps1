class ApplicationPolicy : BaseResourceModel {
    [FqName] $ParentFqName
    [String] $ResourceName = 'application-policy-set'
    [String] $ParentType = 'policy-management'
    [FqName[]] $TagFqNames
    [FqName[]] $FirewallPolicyFqNames

    ApplicationPolicy([FqName[]] $FirewallPolicyFqNames, [FqName[]] $TagFqNames, [String] $Name, [String] $ProjectName) {
        $this.Name = $Name
        $this.ParentFqName = [FqName]::new(@('default-policy-management', $ProjectName))
        $this.Tags = $TagFqNames
        $this.FirewallPolicyFqNames = $FirewallPolicyFqNames
    }

    hidden [Hashtable[]] GetFPReferences() {
        $References = @()
        foreach ($FPFqName in $this.FirewallPolicyFqNames) {
            $Ref = @{
                "to" = $FPFqName.ToStringArray()
                "attr" = @{
                    "sequence" = "0"
                }
            }
            $References += $Ref
        }

        return $References
    }

    hidden [Hashtable[]] GetTagReferences() {
        $References = @()
        foreach ($TagFqName in $this.TagFqNames) {
            $Ref = @{
                "to" = $TagFqName.ToStringArray()
            }
            $References += $Ref
        }

        return $References
    }


    [Hashtable] GetRequest() {
        $Request = @{
            $this.ResourceName = @{}
        }

        $Request.$($this.ResourceName).Add('firewall_policy_refs', $this.GetFPReferences())
        $Request.$($this.ResourceName).Add('tag_refs', $this.GetTagReferences())

        return $Request
    }
}
