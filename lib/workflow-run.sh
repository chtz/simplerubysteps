#!/bin/bash

export STACK_NAME=$(basename "$PWD")

export STEP_FUNCTIONS_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --output text --query "Stacks[].Outputs[]"|grep StepFunctionsStateMachineARN|awk '{print $2}')

tee /tmp/statemachineinput.json > /dev/null
STATE_MACHINE_INPUT="$(cat /tmp/statemachineinput.json)"

EXECUTION_ARN=$(aws stepfunctions start-execution \
  --state-machine-arn $STEP_FUNCTIONS_ARN \
  --input "$STATE_MACHINE_INPUT" \
  --query "executionArn" \
  --output text)

echo "Started execution: $EXECUTION_ARN"

while true; do
  STATUS=$(aws stepfunctions describe-execution \
    --execution-arn $EXECUTION_ARN \
    --query "status" \
    --output text)

  if [[ "$STATUS" == "SUCCEEDED" ]]; then
    break
  elif [[ "$STATUS" == "FAILED" || "$STATUS" == "TIMED_OUT" || "$STATUS" == "ABORTED" ]]; then
    echo "Execution failed with status: $STATUS"
    exit 1
  else
    sleep 5
  fi
done

OUTPUT=$(aws stepfunctions describe-execution \
  --execution-arn $EXECUTION_ARN \
  --query "output" \
  --output text)

echo "Execution output: $OUTPUT"
