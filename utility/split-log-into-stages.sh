#!/bin/bash

set -e
set -u
IFS=$'\n'

cd "$(dirname "$1")"

full_log_gz=$(basename "$1")
gunzip --keep "$full_log_gz"
full_log=$(basename "$1" .gz)

function get_stage_regexp() {
    echo '^.{29}(?:\[Pipeline\] )?\[('"$1"')\].*$'
}

stage_regexp=$(get_stage_regexp '[A-Za-z -]+')

stages=$(perl -lne "s/$stage_regexp/\$1/ or next; print" < "$full_log" | sort --unique)

for stage in $stages
do
    stage_slug=$(echo "$stage" | tr '[:upper:]' '[:lower:]' | tr --squeeze ' ' '-')
    stage_log_filename="log.$stage_slug.txt.gz"
    this_stage_regexp=$(get_stage_regexp "$stage")
    echo "copying '$stage' log to $stage_log_filename"
    grep --perl-regexp "$this_stage_regexp" "$full_log" | gzip > "$stage_log_filename"
done

non_tagged_filename='log.cloning-and-tests.txt.gz'

echo "copying remaining part of log to $non_tagged_filename"
grep --perl-regexp --invert-match "$stage_regexp" "$full_log" | gzip > "$non_tagged_filename"

rm "$full_log"
