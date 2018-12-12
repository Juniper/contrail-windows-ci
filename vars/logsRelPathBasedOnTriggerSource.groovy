def call(String jobName, String buildNumber, String zuulUuid) {
    if(zuulUuid == null) {
        return "github/${jobName}/${buildNumber}"
    }
    else if(zuulUuid == "") {
        return "${jobName}/${buildNumber}"
    }
    return zuulUuid
}
