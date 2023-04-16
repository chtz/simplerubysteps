#!/bin/bash

# Fetch all the log group names
log_groups=$(aws logs describe-log-groups --query 'logGroups[?starts_with(logGroupName, `/aws/lambda/`)].logGroupName' --output text)

# Loop through the log group names and delete them
for log_group in $log_groups; do
  echo "Deleting log group: $log_group"
  aws logs delete-log-group --log-group-name "$log_group"
done

echo "All Lambda log groups have been deleted."
