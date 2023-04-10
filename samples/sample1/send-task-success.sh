#!/bin/bash

tee /tmp/taskoutput.json > /dev/null
TASK_OUTPUT="$(cat /tmp/taskoutput.json)"

aws stepfunctions send-task-success --task-token="$1" --task-output "$TASK_OUTPUT"
