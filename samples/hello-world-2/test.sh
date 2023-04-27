#!/bin/bash

srs deploy

RESULT=$(echo '{"hello":"Hallo"}'|srs start|jq -r ".output"|jq -r ".hello_world")

if [ "$RESULT" != "Hallo Welt!!" ]; then
    echo "hello-world-2 test: failed"
    exit 1
fi

echo "hello-world-2 test: success"
