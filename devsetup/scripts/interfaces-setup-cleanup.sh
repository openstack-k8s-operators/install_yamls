#!/bin/bash
set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit
fi

MAC_ADDRESS=$(virsh --connect=qemu:///system dumpxml $INSTANCE_NAME | xmllint --xpath "string(/domain/devices/interface/source[@network=\"$NETWORK_NAME\"]/../mac/@address)" - 2>/dev/null)
if [ -n "${MAC_ADDRESS}" ]; then
    virsh --connect=qemu:///system detach-interface $INSTANCE_NAME network --mac $MAC_ADDRESS
    # First try to remove the DHCP static IP entry by MAC, if it fails try by hostname
    if virsh --connect=qemu:///system net-update $NETWORK_NAME delete ip-dhcp-host "<host mac='$MAC_ADDRESS'/>" --config --live 2>/dev/null; then
        DHCP_REMOVED=true
    fi
fi

# Without MAC we try to remove it using the host name or IP address
if [ -z "${DHCP_REMOVED}" ]; then
    if ! virsh --connect=qemu:///system net-update $NETWORK_NAME delete ip-dhcp-host "<host name='$INSTANCE_NAME'/>" --config --live 2>/dev/null; then
        virsh --connect=qemu:///system net-update $NETWORK_NAME delete ip-dhcp-host "<host ip='$IP_ADDRESS'/>" --config --live 2>/dev/null
    fi
fi

sleep 5

if [ -n "$BGP" ]; then
    # We don't destroy the PCI devices here but before adding them, to avoid having to restart the CRC VM twice

    virsh --connect=qemu:///system detach-interface $INSTANCE_NAME network --mac $BGP_NIC_1_MAC
    sleep 5
    virsh --connect=qemu:///system detach-interface $INSTANCE_NAME network --mac $BGP_NIC_2_MAC
    sleep 5
fi
