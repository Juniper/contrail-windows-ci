def call(String logsFolder) {
    def command = "flakes/grep-dir.sh '$logsFolder'"
    def status = sh script: command, returnStatus: true

    return status == 0
}
