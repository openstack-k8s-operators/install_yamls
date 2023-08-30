#!/bin/bash
# set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit
fi

NETWORK_NAME=${NETWORK_NAME:-$DEFAULT_NETWORK_NAME}

function usage {
    echo
    echo "options:"
    echo "  --create        Attach network"
    echo "  --cleanup       Detach network"
    echo
}

MY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$MY_TMP_DIR"' EXIT


function attach_network {
    local mac_address
    mac_address=$(echo -n $MAC_PREFIX; dd bs=1 count=3 if=/dev/random 2>/dev/null | hexdump -v -e '/1 "-%02X"' | tr '-' ':')
    virsh --connect=qemu:///system \
        attach-interface crc \
        --source "${NETWORK_NAME}" \
        --type network \
        --model virtio \
        --mac "$mac_address" \
        --config \
        --persistent
    return $?
}

function detach_network {
    local mac_address
    mac_address=$(virsh --connect=qemu:///system domiflist crc | grep "${NETWORK_NAME}" | awk '{print $5}')
    if [ -n "$mac_address" ]; then
        virsh --connect=qemu:///system detach-interface crc network --mac "$mac_address"
        sleep 5
    fi
}

function create {
    if ! attach_network; then
        echo "Hot-plugging network interface failed, stopping the crc instance ..."
        crc stop
        attach_network
        crc start
    fi
    sleep 10;
}

function cleanup {
    detach_network
}

case "$1" in
    "--create")
        ACTION="CREATE";
    ;;
    "--cleanup")
        ACTION="CLEANUP";
    ;;
    *)
        echo >&2 "Invalid option: $*";
        usage;
        exit 1
    ;;
esac

if [ -z "$ACTION" ]; then
    echo "Not enough input arguments"
    usage
    exit 1
fi

if [ "$ACTION" == "CREATE" ]; then
    create
elif [ "$ACTION" == "CLEANUP" ]; then
    cleanup
fi
