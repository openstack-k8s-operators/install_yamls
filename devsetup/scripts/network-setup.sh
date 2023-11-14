#!/bin/bash
# set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit
fi

LIBVIRT_URL=${LIBVIRT_URL:-qemu:///system}
VIRSH_CMD=${VIRSH_CMD:-virsh --connect=$LIBVIRT_URL}

DEFAULT_NETWORK_NAME=net-iso

NETWORK_NAME=${NETWORK_NAME:-$DEFAULT_NETWORK_NAME}
IPV4_ADDRESS=${IPV4_ADDRESS:-""}
IPV4_NAT=${IPV4_NAT:-true}
IPV6_ADDRESS=${IPV6_ADDRESS:-""}

MY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$MY_TMP_DIR"' EXIT

function usage {
    echo
    echo "options:"
    echo "  --create        Define and start the libvirt network"
    echo "  --cleanup       Destroy and undefine the libvirt network"
    echo "  --network-name  Libvirt network name (Default: $DEFAULT_NETWORK_NAME)"
    echo "  --ipv4-address  IPv4 Address for libvirt network bridge"
    echo "  --ipv6-address  IPv6 Address for libvirt network bridge"
    echo "  --ipv4-nat      When specified IPv4 NAT is enabled. (Default: true)"
    echo
}

function create {
    local temp_file
    temp_file=$(mktemp -p "$MY_TMP_DIR")
    cat << EOF > "$temp_file"
<network>
  <name>$NETWORK_NAME</name>
  <bridge name='$NETWORK_NAME' stp='on' delay='0'/>
</network>
EOF

    if [ -n "${IPV4_ADDRESS}" ]; then
        cat $temp_file | xmlstarlet edit --omit-decl --pf --subnode '/network' --type text --name '' \
            --value "<ip family='ipv4' address='${IPV4_ADDRESS%%/*}' prefix='${IPV4_ADDRESS##*/}'/>" \
            | tee ${temp_file}
        if [ "${IPV4_NAT}" = "true" ]; then
            cat $temp_file | xmlstarlet edit --omit-decl --pf --subnode '/network' --type text --name '' \
                --value "<forward mode='nat'><nat><port start='1024' end='65535'/></nat></forward>" \
                | tee ${temp_file}
        fi
    fi
    if [ -n "${IPV6_ADDRESS}" ]; then
        cat $temp_file | xmlstarlet edit --omit-decl --pf --subnode '/network' --type text --name '' \
            --value "<ip family='ipv6' address='${IPV6_ADDRESS%%/*}' prefix='${IPV6_ADDRESS##*/}'/>" \
            | tee ${temp_file}
    fi
    cat "$temp_file" | xmlstarlet unescape | tee ${temp_file}

    $VIRSH_CMD net-define "$temp_file"
    $VIRSH_CMD net-autostart "$NETWORK_NAME"
    $VIRSH_CMD net-start "$NETWORK_NAME"
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
    "--ipv4-address")
        IPV4_ADDRESS="$2";
        shift
    ;;
    "--ipv6-address")
        IPV6_ADDRESS="$2";
        shift
    ;;
    "--ipv4-nat")
        IPV4_NAT=true
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
