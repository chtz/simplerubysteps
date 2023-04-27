#!/bin/bash

srs deploy

RESULT=$(echo '{}'|srs start|jq -r ".output"|jq -r ".expected_error")

if [ "$RESULT" != "yes" ]; then
    echo "error1 test: failed"
    exit 1
fi

echo "error1 test: success"
