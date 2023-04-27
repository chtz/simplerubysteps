#!/bin/bash

srs deploy

./sample-task-worker.sh &

RESULT=$(./start-callbackbranch.sh|jq -r ".output"|jq -r ".t5")

if [ "$RESULT" != "done" ]; then
    echo "sample1 test: failed"
    exit 1
fi

echo "sample1 test: success"
