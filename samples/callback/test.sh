#!/bin/bash

srs deploy

./sample-task-worker.sh &

RESULT=$(./start-callbackbranch.sh|jq -r ".t2")

if [ "$RESULT" != "done" ]; then
    echo "Callback test: failed"
    exit 1
fi

echo "Callback test: success"
