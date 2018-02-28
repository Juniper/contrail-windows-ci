def call(Map logServer, String src, String destDir) {
    script {
        if (fileExists(src)) {
            sh "ssh ${logServer.user}@${logServer.addr} \"mkdir -p ${destDir}\""
            sh "rsync ${src} ${logServer.user}@${logServer.addr}:${destDir}"
        } else {
            echo "publishToLogServer: File '${src}' does not exist. Omitting"
        }
    }
}
