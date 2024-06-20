#!/bin/bash

n=0
retries="${1:-5}"  # Number of retries with a default value of 5

while true; do
    make nncp && break
    make nncp_cleanup
    n=$((n+1))
    if (( n >= retries )); then
        echo "Failed to run 'make nncp' target. Aborting"
        exit 1
    fi
    sleep 10
done
