def call() {
    def SUPPORTED_VERSIONS = [ '2016', '2019' ]

    if(!env.WINDOWS_VERSION) {
        env.WINDOWS_VERSION = '2016'
        return
    }

    if(!SUPPORTED_VERSIONS.contains(env.WINDOWS_VERSION)) {
        error('Unsupported Windows Server version')
    }
}
