# Create AWS Step Functions State Machine with ruby DSL

```
cd samples/sample1
vi workflow.rb
```

# Create CloudFormation stack with Step Functions State Machine and supporting Lambda functions

```
export AWS_PROFILE=...
cd samples/sample1
simplerubysteps-deploy
```

# Trigger State Machine Execution and wait for completion

```
export AWS_PROFILE=...          
cd samples/sample1
echo '{"foo": "John Wick"}' | simplerubysteps-workflow-run
```

# Delete CloudFormation stack

```
export AWS_PROFILE=...
cd samples/sample1
simplerubysteps-destroy
```
