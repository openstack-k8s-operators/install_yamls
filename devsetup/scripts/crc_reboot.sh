#!/bin/bash

if [ -z "$TIMEOUT" ]; then
    echo "$0: Please set TIMEOUT."
    exit 1
fi

virsh --connect=qemu:///system destroy crc
timeout --foreground ${TIMEOUT} bash -c 'until $(virsh --connect=qemu:///system list --all | grep crc | grep -q "shut off"); do sleep 1; done'
virsh --connect=qemu:///system start crc
timeout --foreground ${TIMEOUT} bash -c 'until $(virsh --connect=qemu:///system list --all | grep crc | grep -q "running"); do sleep 1; done'

