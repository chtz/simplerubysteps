#!/bin/bash

# echo '{"foo": "James Bond"}'|simplerubysteps-workflow-run

echo '{"foo": "James Bond"}'|ruby ../../lib/tool.rb start --wait true|jq -r ".output"|jq
