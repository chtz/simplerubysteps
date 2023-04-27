#!/bin/bash

srs deploy

RESULT=$(echo '{"bar":"foo"}'|srs start|jq -r ".output"|jq -r ".t2")

if [ "$RESULT" != "yes" ]; then
    echo "sample2 test: failed"
    exit 1
fi

echo "sample2 test: success"
