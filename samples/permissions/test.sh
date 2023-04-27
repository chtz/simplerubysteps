#!/bin/bash

srs deploy

RESULT=$(echo '{}'|srs start|jq -r ".output")

if [[ "$RESULT" == *"bucket"* ]]; then
    echo "permission test: success"
else
    echo "permission test: failed"
    exit 1
fi
