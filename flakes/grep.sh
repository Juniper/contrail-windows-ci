#!/bin/bash

set -u
set -o pipefail

DIR=$(dirname $BASH_SOURCE)

grep --extended-regexp --file "$DIR/patterns.txt" "$@"
