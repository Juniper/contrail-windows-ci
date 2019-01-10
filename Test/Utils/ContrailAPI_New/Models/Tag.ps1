class Tag : BaseResourceModel {
    [String] $TypeName
    [String] $Value
    [FqName] $ParentFqName
    [String] $ResourceName = 'tag'
    [String] $ParentType = 'project'

    Tag([String] $TypeName, [string] $Value, [String] $ParentFqName) {
        $this.Value = $Value
        $this.TypeName = $TypeName
        $this.ParentFqName = [FqName]::new(@('default-domain', $ParentFqName))
    }

    [string] GetName() {
        return "$( $this.TypeName )=$( $this.Value )"
    }

    [FqName] GetFqName() {
        return [FqName]::New($this.ParentFqName, $this.GetName())
    }

    [Hashtable] GetRequest() {
        return @{
            $this.ResourceName = @{
                tag_type_name = $this.TypeName
                tag_value = $this.Value
            }
        }
    }
}
