#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "Run with file path as arugment"
    exit 1
fi

FILEPATH=$1
NEW_PATH=${FILEPATH}_ruby
fgrep '[Ruby]' $FILEPATH | fgrep -v 'Yast.cc' > $NEW_PATH

echo "Cleaned log was written to $NEW_PATH"