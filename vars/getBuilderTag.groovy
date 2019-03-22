def call() {
    def BUILDER_TAGS = [
        '2016': 'builder',
        '2019': 'builder2019'
    ]

    return BUILDER_TAGS.get(env.WINDOWS_VERSION)
}
