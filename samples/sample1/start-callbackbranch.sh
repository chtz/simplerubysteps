#!/bin/bash

#echo '{"foo": "John Wick"}'|simplerubysteps-workflow-run

echo '{"foo": "John Wick"}'|ruby ../../lib/tool.rb start --wait true|jq
