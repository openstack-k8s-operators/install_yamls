#!/bin/bash

n=0
retries=3

while true; do
    make crc_storage_cleanup && break
    n=$((n+1))
    if (( n >= retries )); then
        echo "Failed to run 'make crc_storage_cleanup' target. Aborting"
        exit 1
    fi
    sleep 10
done
