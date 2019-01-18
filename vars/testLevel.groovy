enum TestLevel {
    None, Sanity, All
}

def runAll() {
    if (env.TEST_LEVEL == null) {
        return false
    }

    return (env.TEST_LEVEL as TestLevel) == TestLevel.All
}

def runAny() {
    if (env.TEST_LEVEL == null) {
        return true
    }

    return (env.TEST_LEVEL as TestLevel) != TestLevel.None
}
