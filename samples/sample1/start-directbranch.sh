#!/bin/bash

echo '{"foo": "James Bond"}'|srs start --wait|jq -r ".output"|jq
