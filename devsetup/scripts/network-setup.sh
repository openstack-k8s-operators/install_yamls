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
IPV6_NAT64=${IPV6_NAT64:-false}
NAT64_TAYGA_IPV6_PREFIX=${NAT64_TAYGA_IPV6_PREFIX:-""}
NAT64_HOST_IPV6=${NAT64_HOST_IPV6:""}

MY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$MY_TMP_DIR"' EXIT

function usage {
    echo
    echo "options:"
    echo "  --create        Define and start the libvirt network"
    echo "  --cleanup       Destroy and undefine the libvirt network"
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
        if [ "${IPV6_NAT64}" = "true" ]; then
            # Set forward mode to open to disable all Libvirt firewall rules.
            cat $temp_file | xmlstarlet edit --omit-decl --pf --subnode '/network' --type text --name '' \
                --value "<forward mode='open'/>" \
                | tee ${temp_file}
        fi
    fi
    cat "$temp_file" | xmlstarlet unescape | tee ${temp_file}

    $VIRSH_CMD net-define "$temp_file"
    $VIRSH_CMD net-autostart "$NETWORK_NAME"
    $VIRSH_CMD net-start "$NETWORK_NAME"

    if [ "${IPV6_NAT64}" = "true" ]; then
        # Add a route on the hypervisor for the NAT64 IPv6 prefix
        sudo ip -6 route add ${NAT64_TAYGA_IPV6_PREFIX} dev nat64 via ${NAT64_HOST_IPV6%%/*}
        # Add firewall rules to allow forwarding the NAT64 IPv6 prefix
        sudo ip6tables -I LIBVIRT_FWI 1 -d ${NAT64_TAYGA_IPV6_PREFIX} -o nat64 -j ACCEPT
        sudo ip6tables -I LIBVIRT_FWO 1 -s ${NAT64_TAYGA_IPV6_PREFIX} -j ACCEPT
    fi
}

function cleanup {
    if virsh --connect=qemu:///system net-list --name | grep "$NETWORK_NAME"; then
        virsh --connect=qemu:///system net-destroy "$NETWORK_NAME" || true
        virsh --connect=qemu:///system net-undefine "$NETWORK_NAME" || true
    fi
    if [ "${IPV6_NAT64}" = "true" ]; then
        sudo ip -6 route del ${NAT64_TAYGA_IPV6_PREFIX}
    fi
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
