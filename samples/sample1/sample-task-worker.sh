#!/bin/bash

TOKEN=$(simplerubysteps log --extract_pattern 'callback_token=(.+)')

echo '{"willo":"billo"}'|srs task-success --token $TOKEN > /dev/null
