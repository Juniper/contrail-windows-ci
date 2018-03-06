def call(String filePath) {
    def contents = readFile(filePath)

    def controller = contents.split('\n').find { line ->
        line.matches('^.*-controller;.*$')
    }

    def address = controller.split(';')[1].split(',')[0]

    return address
}
