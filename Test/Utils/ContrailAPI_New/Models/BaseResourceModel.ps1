class BaseResourceModel {
    [String] $ResourceName
    [String] $ParentType
    [Dependency[]] $Dependencies = @()

    # Override in derivered
    hidden [Hashtable] GetRequest() {
        throw "Operations Add/Set not permited on object: $($this.GetType().Name)"
    }
}

class Dependency {
    [String] $ResourceName
    [String] $ReferencesField

    Dependency([String] $ResourceName, [String] $ReferencesField) {
        $this.ResourceName = $ResourceName
        $this.ReferencesField = $ReferencesField
    }
}
