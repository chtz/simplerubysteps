#!/bin/bash

echo "Enter a number"
read NUMBER
echo "{\"number\":$NUMBER}" | srs start | jq -r ".output" | jq -r ".result"

