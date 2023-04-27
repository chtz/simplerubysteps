#!/bin/bash

srs deploy

RESULT=$(echo "123"|./demo.sh|tail -n 1)

if [ "$RESULT" != "123 is odd" ]; then
    echo "hello-world test: failed"
    exit 1
fi

echo "hello-world test: success"
