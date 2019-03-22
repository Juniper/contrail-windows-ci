def call() {
    def TESTBED_TEMPLATES = [
        '2016': 'Template-testbed-201903190303',
        '2019': 'Template-testbed2019-201903190401'
    ]

    return TESTBED_TEMPLATES.get(env.WINDOWS_VERSION)
}
