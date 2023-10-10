#!/bin/bash
set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit 1
fi

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ROUTE_LIBVIRT_NETWORKS=${ROUTE_LIBVIRT_NETWORKS:-""}

source ${SCRIPTPATH}/common.sh

function usage {
    echo
    echo "options:"
    echo "  --create   Set up libvirt network routing"
    echo "  --cleanup  Tear down libvirt network routing"
    echo
}


function create {
    # Set up firewall rules so that traffic between libvirt networks are routed (e.g no NAT)
    local libvirt_networks
    libvirt_networks=$1

    # Create up chains

    # FORWARD chains
    if ! sudo iptables -n -L FORWARD | grep DSETUP_FWD_PRE_VIRT; then
        sudo iptables -N DSETUP_FWD_PRE_VIRT
        sudo iptables -I FORWARD -j DSETUP_FWD_PRE_VIRT
    fi

    # POSTROUTING chains
    if ! sudo iptables -t nat -n -L POSTROUTING | grep DSETUP_PRT_PRE_VIRT; then
        sudo iptables -t nat -N DSETUP_PRT_PRE_VIRT
        sudo iptables -t nat -I POSTROUTING -j DSETUP_PRT_PRE_VIRT
    fi

    # Get the bridge name and ip subnet (cidr) from libvirt
    for net in ${libvirt_networks//,/ }; do
        # bridge_ip_subnets list of strings: "<bridge_name>;<ip_subnet> <bridge_name>;<ip_subnet>"
        bridge_ip_subnets+=" $(get_libvirt_net_bridge ${net});$(get_libvirt_net_ip_subnet ${net})"
    done

    for a_net in ${bridge_ip_subnets}; do
        for b_net in ${bridge_ip_subnets}; do
            if [ ${a_net} != ${b_net} ]; then
                a_bridge=${a_net%;*}
                b_bridge=${b_net%;*}
                a_ip_subnet=${a_net#*;}
                b_ip_subnet=${b_net#*;}
                sudo iptables -I DSETUP_FWD_PRE_VIRT -i ${a_bridge} -o ${b_bridge} -s ${a_ip_subnet} -d ${b_ip_subnet} -j ACCEPT
                sudo iptables -t nat -I DSETUP_PRT_PRE_VIRT -s ${a_ip_subnet} -d ${b_ip_subnet} -j RETURN
            fi
        done
    done
}

function cleanup {
    # Clean up the firewall rules for routing

    # FORWARD chains
    if sudo iptables -n -L FORWARD | grep DSETUP_FWD_PRE_VIRT; then
        sudo iptables -D FORWARD -j DSETUP_FWD_PRE_VIRT || true
    fi
    if sudo iptables -S | grep DSETUP_FWD_PRE_VIRT; then
        sudo iptables -F DSETUP_FWD_PRE_VIRT || true
        sudo iptables -X DSETUP_FWD_PRE_VIRT || true
    fi

    # POSTROUTING chains
    if sudo iptables -n -t nat -L POSTROUTING | grep DSETUP_PRT_PRE_VIRT; then
        sudo iptables -t nat -D POSTROUTING -j DSETUP_PRT_PRE_VIRT || true
    fi
    if sudo iptables -t nat -S | grep DSETUP_PRT_PRE_VIRT; then
        sudo iptables -t nat -F DSETUP_PRT_PRE_VIRT || true
        sudo iptables -t nat -X DSETUP_PRT_PRE_VIRT || true
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
    create $(deduplicate_string_list ${ROUTE_LIBVIRT_NETWORKS} ",")
elif [ "$ACTION" == "CLEANUP" ]; then
    cleanup
fi
