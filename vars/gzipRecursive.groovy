def call(String pattern) {
  sh "find . -name \"$pattern\" -exec gzip {} \;"
}
