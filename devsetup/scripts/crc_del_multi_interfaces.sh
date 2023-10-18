#!/bin/bash

if [ -z "$TIMEOUT" ]; then
    echo "$0: Please set TIMEOUT."
    exit 1
fi

NEED_REBOOT=0

for network in data management external; do
    MAC_ADDRESS=$(virsh --connect=qemu:///system dumpxml crc | grep "source network='$network'" -B1 | grep mac | cut -d"'" -f2);
    if [ "x$MAC_ADDRESS" != "x" ]; then
        NEED_REBOOT=1
        virsh --connect=qemu:///system detach-interface --domain crc --type network --mac $$MAC_ADDRESS --config;
    fi
    sleep 1
done
if [[ $NEED_REBOOT == 1 ]]; then
    bash scripts/crc_reboot.sh
fi
