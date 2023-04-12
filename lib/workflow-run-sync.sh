#!/bin/bash

export STACK_NAME=$(basename "$PWD")

export STEP_FUNCTIONS_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --output text --query "Stacks[].Outputs[]"|grep StepFunctionsStateMachineARN|awk '{print $2}')

tee /tmp/statemachineinput.json > /dev/null
STATE_MACHINE_INPUT="$(cat /tmp/statemachineinput.json)"

aws stepfunctions start-sync-execution --state-machine-arn $STEP_FUNCTIONS_ARN --input "$STATE_MACHINE_INPUT" --query "output" --output text
