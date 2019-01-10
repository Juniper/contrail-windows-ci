class Tag : BaseResourceModel {
    [String] $TypeName
    [string] $Value
    [FqName] $ParentFqName
    [String] $ResourceName = 'tag'
    [String] $ParentType = 'project'

    Tag([String] $TypeName, [string] $Value, [String] $ParentFqName) {
        $this.Value = $Value
        $this.TypeName = $TypeName
        $this.ParentFqName = [FqName]::new($ParentFqName)
    }

    [FqName] GetFqName() {
        $Name = "$( $this.TypeName )=$( $this.Value )"
        return [FqName]::New($this.ParentFqName, $Name)
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
