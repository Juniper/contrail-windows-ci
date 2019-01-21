def call(String srcDir, String authority, String destDir) {
    def remoteDir = authority + ":" + destDir + "/jenkins_logs"
    def new_path = destDir + "/jenkins_logs"
    shellCommand "ssh", ["zuul-win@logs.opencontrail.org",  "mkdir", "-p", new_path]
    shellCommand "ssh", ["zuul-win@logs.opencontrail.org", "chmod", "-R", "775", new_path]
    shellCommand "rsync", ["--prune-empty-dirs", "-r", srcDir + "/", remoteDir]
    shellCommand "ssh", ["zuul-win@logs.opencontrail.org", "sudo", "/bin/chown", "-R", "zuul:zuul", destDir]
}