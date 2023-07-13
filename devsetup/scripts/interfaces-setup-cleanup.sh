#!/bin/bash
# set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit
fi

MAC_ADDRESS=$(virsh --connect=qemu:///system net-dumpxml default | grep crc | sed -e "s/.*mac='\(.*\)' name.*/\1/"); \
virsh --connect=qemu:///system detach-interface crc network --mac "$MAC_ADDRESS"
virsh --connect=qemu:///system net-update default delete ip-dhcp-host "<host name='crc'/>" --config --live
sleep 5

if [ -n "$BGP" ]; then
    # We don't destroy the PCI devices here but before adding them, to avoid having to restart the CRC VM twice

    virsh --connect=qemu:///system detach-interface crc network --mac $BGP_NIC_1_MAC
    sleep 5
    virsh --connect=qemu:///system detach-interface crc network --mac $BGP_NIC_2_MAC
    sleep 5
fi
