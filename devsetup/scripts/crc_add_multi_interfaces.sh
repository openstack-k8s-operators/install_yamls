#!/bin/bash

if [ -z "$TIMEOUT" ]; then
    echo "$0: Please set TIMEOUT."
    exit 1
fi

NEED_REBOOT=0

for network in data management external; do
    export NETWORK_NAME=$network
    bash scripts/bmaas/network-attachement-definition.sh --create
    if [[ $? == 0 ]]; then
        NEED_REBOOT=1
    fi
    sleep 1
done
if [[ $NEED_REBOOT == 1 ]]; then
    bash scripts/crc_reboot.sh
fi
