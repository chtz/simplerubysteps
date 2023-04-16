#!/bin/bash

echo '{"foo": "John Wick"}'|srs start --wait|jq -r ".output"
