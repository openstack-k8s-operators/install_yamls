#!/bin/bash

n=0
retries="${1:-3}"  # Number of retries with a default value of 3

while true; do
    make crc_storage && break
    n=$((n+1))
    if (( n >= retries )); then
        echo "Failed to run 'make crc_storage' target. Aborting"
        exit 1
    fi
    sleep 10
done
