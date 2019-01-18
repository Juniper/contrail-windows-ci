#!/bin/bash

set -u
set -o pipefail

IFS=$'\n';
DIR=$(dirname $BASH_SOURCE)

for f in $(find $1 -name '*.txt.gz')
do
    zcat $f | $DIR/grep.sh > /dev/null
    if [ $? -eq 0 ]
    then
        exit 0
    fi
done

unset IFS
exit 1
