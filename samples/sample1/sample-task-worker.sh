#!/bin/bash

TOKEN=$(simplerubysteps log --extract_pattern 'callback_token=(.+)')

echo '{"willo":"billo"}'|simplerubysteps task-success --token $TOKEN
