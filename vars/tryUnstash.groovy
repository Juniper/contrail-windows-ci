def call(String stashName) {
    try {
        unstash stashName
        return true
    } catch (Exception ex) {
        return false
    }
}
