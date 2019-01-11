class Tag : BaseResourceModel {
    [String] $TypeName
    [String] $Value
    [String] $ResourceName = 'tag'
    [String] $ParentType = 'project'

    Tag([String] $TypeName, [String] $Value, [String] $ProjectName) {
        $this.Value = $Value
        $this.TypeName = $TypeName
        $this.ParentFqName = [FqName]::new(@('default-domain', $ProjectName))
    }

    [String] GetName() {
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
