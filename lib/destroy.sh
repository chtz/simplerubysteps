#!/bin/bash

export STACK_NAME=$(basename "$PWD")

export DEPLOY_BUCKET=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --output text --query "Stacks[].Outputs[]"|grep DeployBucket|awk '{print $2}')

aws s3 rm s3://$DEPLOY_BUCKET --recursive

aws cloudformation delete-stack \
  --stack-name $STACK_NAME 
