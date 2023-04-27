#!/bin/bash

srs deploy

RESULT=$(echo '{"hi":"Hallo"}'|srs start --wait|jq -r ".output"|jq -r ".hello_world")

if [ "$RESULT" != "Hallo Welt" ]; then
    echo "sample3 test: failed"
    exit 1
fi

echo "sample3 test: success"
