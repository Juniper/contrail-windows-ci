#!/bin/bash

set -u
set -o pipefail

DIR=$(dirname ${BASH_SOURCE[0]})

grep --extended-regexp --file "$DIR/patterns.txt" "$@"
