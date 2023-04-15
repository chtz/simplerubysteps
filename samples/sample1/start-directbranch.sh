#!/bin/bash

echo '{"foo": "James Bond"}'|simplerubysteps start --wait true|jq -r ".output"|jq
