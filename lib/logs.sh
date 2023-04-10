#!/bin/bash

export STACK_NAME=$(basename "$PWD")

export FUNCTION_NAME=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --output text --query "Stacks[].Outputs[]"|grep LambdaFunctionName|awk '{print $2}')

aws logs tail /aws/lambda/$FUNCTION_NAME
