#!/bin/bash

echo '{"foo": "John Wick"}'|simplerubysteps start --wait true|jq
