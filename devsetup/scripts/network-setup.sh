#!/bin/bash
# set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit
fi

DEFAULT_NETWORK_NAME=crc-net-iso
DEFAULT_IPADDRESS=172.16.0.1
DEFAULT_NETMASK=255.255.255.0

NETWORK_NAME=${NETWORK_NAME:-$DEFAULT_NETWORK_NAME}
IPADDRESS=${NETWORK_IPADDRESS:-$DEFAULT_IPADDRESS}
NETMASK=${NETWORK_NETMASK:-$DEFAULT_NETMASK}

MY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$MY_TMP_DIR"' EXIT

function usage {
    echo
    echo "options:"
    echo "  --create        Define and start the libvirt network"
    echo "  --cleanup       Destroy and undefine the libvirt network"
    echo "  --network-name  Libvirt network name (Default: $DEFAULT_NETWORK_NAME)"
    echo "  --ip-address    IP Address for libvirt network bridge (Default: $DEFAULT_IPADDRESS)"
    echo "  --netmask       Netmask for the libvirt network bridge (Default: $DEFAULT_NETMASK)"
    echo
}

function create {
    local temp_file
    temp_file=$(mktemp -p "$MY_TMP_DIR")
    cat << EOF > "$temp_file"
<network>
  <name>$NETWORK_NAME</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='$NETWORK_NAME' stp='on' delay='0'/>
  <ip address='$IPADDRESS' netmask='$NETMASK'/>
</network>
EOF
    virsh --connect=qemu:///system net-define "$temp_file"
    virsh --connect=qemu:///system net-autostart "$NETWORK_NAME"
    virsh --connect=qemu:///system net-start "$NETWORK_NAME"
}

function cleanup {
    if virsh --connect=qemu:///system net-list --name | grep "$NETWORK_NAME"; then
        virsh --connect=qemu:///system net-destroy "$NETWORK_NAME" || true
        virsh --connect=qemu:///system net-undefine "$NETWORK_NAME" || true
    fi
}

case "$1" in
    "--create")
        ACTION="CREATE";
    ;;
    "--cleanup")
        ACTION="CLEANUP";
    ;;
    "--network-name")
        NETWORK_NAME="$2";
        shift
    ;;
    "--ip-address")
        IPADDRESS="$2";
        shift
    ;;
    "--netmask")
        NETMASK="$2";
        shift
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
