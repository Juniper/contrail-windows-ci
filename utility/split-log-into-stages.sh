#!/bin/bash

set -e
set -u
IFS=$'\n'

cd "$(dirname "$1")"

full_log_gz=$(basename "$1")
gunzip --keep "$full_log_gz"
full_log=$(basename "$1" .gz)

function get_stage_regexp() {
    # * Match <Tag> from `<timestamp> | [<Tag>] ...`
    # * Don't count [Pipeline] as a separate tag
    # * Don't count [Directory] in `<timestamp> | [Directory] Running shell script` as separate tag.
    echo '^.{29}(?:\[Pipeline\] )?\[(?!Pipeline)('"$1"')\](?! Running (?:PowerShell|shell) script$).*$'
}

stage_regexp=$(get_stage_regexp '[\w -]+')

stages=$(perl -lne "s/$stage_regexp/\$1/ or next; print" < "$full_log" | sort --unique)

for stage in $stages
do
    stage_slug=$(echo "$stage" | tr '[:upper:]' '[:lower:]' | tr --squeeze ' ' '-')
    stage_log_filename="log.$stage_slug.txt.gz"
    this_stage_regexp=$(get_stage_regexp "$stage")
    echo "copying '$stage' log to $stage_log_filename"
    grep --perl-regexp "$this_stage_regexp" "$full_log" | gzip > "$stage_log_filename"
done

non_tagged_filename='log.cloning-tests-and-post.txt.gz'
echo "copying remaining part of log to $non_tagged_filename"
grep --perl-regexp --invert-match "$stage_regexp" "$full_log" | gzip > "$non_tagged_filename"

rm "$full_log"
