#!/bin/bash

srs deploy

./sample-t1-worker.sh &

RESULT=$(echo '{}'|srs start --wait|jq -r ".output"|jq -r ".expected_t2_timeout")

if [ "$RESULT" != "yes" ]; then
    echo "callback-2 test: failed"
    exit 1
fi

echo "callback-2 test: success"
