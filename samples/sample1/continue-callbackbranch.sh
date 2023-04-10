#!/bin/bash

TOKEN=$(simplerubysteps-logs|grep Token|sort|tail -n 1|ruby -ne 'print $1 if /Token\"=>\"(.+)\"/')

echo "{\"continued\":\"$(date)\"}"|./send-task-success.sh $TOKEN
