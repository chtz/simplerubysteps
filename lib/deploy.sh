#!/bin/bash

SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

export STACK_NAME=$(basename "$PWD")

echo "CF Stack: $STACK_NAME"

export CF_TEMPLATE=$SCRIPT_DIR/../lib/statemachine.yaml

export DEPLOY_BUCKET=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --output text --query "Stacks[].Outputs[]"|grep DeployBucket|awk '{print $2}')

if [[ -n "$DEPLOY_BUCKET" ]]; then
  echo "Deployment bucket found: $DEPLOY_BUCKET"
else
  echo "Creating deloyment bucket"

  echo '[{"ParameterKey":"DeployLambda","ParameterValue":"no"},{"ParameterKey":"DeployStepfunctions","ParameterValue":"no"}]' > /tmp/params.json

  aws cloudformation deploy \
    --template-file $CF_TEMPLATE \
    --stack-name $STACK_NAME \
    --capabilities '["CAPABILITY_IAM","CAPABILITY_NAMED_IAM"]' \
    --parameter-overrides file:///tmp/params.json

  aws cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME || \
    { echo "Stack creation/update failed." >&2; exit 1; }

  export DEPLOY_BUCKET=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --output text --query "Stacks[].Outputs[]"|grep DeployBucket|awk '{print $2}')
fi

echo "Uploading lambda ZIP"

rm -f /tmp/function.zip
zip /tmp/function.zip *.rb
(cd $SCRIPT_DIR/../lib; zip -r /tmp/function.zip *.rb)
(cd $SCRIPT_DIR/../lib; zip -r /tmp/function.zip simplerubysteps/*.rb)

export LAMBDA_SHA=$(shasum /tmp/function.zip | awk '{print $1}')
export UPLOADED_LAMBDA_ZIP=function-$LAMBDA_SHA.zip
aws s3 cp /tmp/function.zip s3://$DEPLOY_BUCKET/$UPLOADED_LAMBDA_ZIP

export LAMBDA_FUNCTION_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --output text --query "Stacks[].Outputs[]"|grep LambdaFunctionARN|awk '{print $2}')

if [[ -n "$LAMBDA_FUNCTION_ARN" ]]; then
  echo "Lambda ARN found: $LAMBDA_FUNCTION_ARN"
else
  echo "Creating lambda"

  echo '[{"ParameterKey":"DeployLambda","ParameterValue":"yes"},{"ParameterKey":"DeployStepfunctions","ParameterValue":"no"},{"ParameterKey":"LambdaS3","ParameterValue":"'$UPLOADED_LAMBDA_ZIP'"}]' > /tmp/params.json

  aws cloudformation deploy \
    --template-file $CF_TEMPLATE \
    --stack-name $STACK_NAME \
    --capabilities '["CAPABILITY_IAM","CAPABILITY_NAMED_IAM"]' \
    --parameter-overrides file:///tmp/params.json

  aws cloudformation wait stack-update-complete \
    --stack-name $STACK_NAME || \
    { echo "Stack update failed." >&2; exit 1; }

  export LAMBDA_FUNCTION_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --output text --query "Stacks[].Outputs[]"|grep LambdaFunctionARN|awk '{print $2}')
fi

echo "Uploading state machine JSON"

ruby -e 'require "./workflow.rb";puts $sm.render.to_json' > /tmp/my-state-machine-definition.json
export STATE_MACHINE_JSON_SHA=$(shasum /tmp/my-state-machine-definition.json | awk '{print $1}')
export UPLOADED_STATE_MACHINE_JSON=statemachine-$STATE_MACHINE_JSON_SHA.zip
aws s3 cp /tmp/my-state-machine-definition.json s3://$DEPLOY_BUCKET/$UPLOADED_STATE_MACHINE_JSON

echo "Updating CloudFormation Stack"

echo '[{"ParameterKey":"DeployLambda","ParameterValue":"yes"},{"ParameterKey":"DeployStepfunctions","ParameterValue":"yes"},{"ParameterKey":"LambdaS3","ParameterValue":"'$UPLOADED_LAMBDA_ZIP'"},{"ParameterKey":"StepFunctionsS3","ParameterValue":"'$UPLOADED_STATE_MACHINE_JSON'"}]' > /tmp/params.json

aws cloudformation deploy \
  --template-file $CF_TEMPLATE \
  --stack-name $STACK_NAME \
  --capabilities '["CAPABILITY_IAM","CAPABILITY_NAMED_IAM"]' \
  --parameter-overrides file:///tmp/params.json

aws cloudformation wait stack-update-complete \
  --stack-name $STACK_NAME || \
  { echo "Stack update failed." >&2; exit 1; }

export STEP_FUNCTIONS_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --output text --query "Stacks[].Outputs[]"|grep StepFunctionsStateMachineARN|awk '{print $2}')

echo "StepFunctions ARN found: $STEP_FUNCTIONS_ARN"

echo "Done"
