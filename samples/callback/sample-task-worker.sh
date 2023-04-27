#!/bin/bash

QUEUE=$(srs stack --output t1Queue)

MESSAGE=$(./wait-for-sqs-message.rb $QUEUE)

INPUT=$(echo "$MESSAGE" | jq -r ".input")
TOKEN=$(echo "$MESSAGE" | jq -r ".token")

echo "$INPUT"|srs task-success --token "$TOKEN" > /dev/null
