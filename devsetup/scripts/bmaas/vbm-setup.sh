#!/bin/bash
# set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit 1
fi

if ! which virt-install > /dev/null; then
    echo
    echo "virt-install not found"
    exit 1
fi

NETWORK_NAME=${NETWORK_NAME:-"crc-bmaas"}
NODE_NAME_PREFIX=${NODE_NAME_PREFIX:-"crc-bmaas"}
NODE_COUNT=${NODE_COUNT:-"1"}
ACTION=""

# Virtual Machine spec
MEMORY=${MEMORY:-4096}
VCPUS=${VCPUS:-2}
DISK_SIZE=${DISK_SIZE:-20}
OS_VARIANT=${OS_VARIANT:-"centos-stream9"}
VIRT_TYPE=${VIRT_TYPE:-"kvm"}
NET_MODEL=${NET_MODEL:-"virtio"}

MY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$MY_TMP_DIR"' EXIT

function usage {
    echo
    echo "options:"
    echo "  --create      Create BMaaS virtual baremetal VMs"
    echo "  --cleanup     Cleanup, delete BMaaS virtual baremteal VMs"
    echo "  --num-nodes   Number of BMaaS virtual baremetal VMs to create (default: 1)"
    echo
}

function create_vm {
    local temp_file
    local name
    temp_file=$(mktemp -p "$MY_TMP_DIR")
    name="$NODE_NAME_PREFIX-$(printf "%02d" "$i")"
    echo "Creating VM: $name"
    virt-install --connect qemu:///system \
        --name "$name" \
        --memory "$MEMORY" \
        --vcpus "$VCPUS" \
        --boot uefi,hd,bootmenu.enable=yes,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no \
        --os-variant "$OS_VARIANT" \
        --disk size="$DISK_SIZE" \
        --network network="$NETWORK_NAME",model="$NET_MODEL" \
        --graphics vnc \
        --virt-type "$VIRT_TYPE" \
        --print-xml \
        > "$temp_file"
    virsh --connect=qemu:///system define "$temp_file"
}

function delete_vm {
    local name
    name=$1
    if virsh --connect=qemu:///system list --all --name | grep "$name"; then
        if [ "$(virsh --connect=qemu:///system domstate "$name")" == "running" ]; then
            virsh --connect=qemu:///system destroy "$name"
        fi
        virsh --connect=qemu:///system undefine "$name" --remove-all-storage --nvram
    fi
}

function create {
    if ! virsh --connect=qemu:///system net-info "$NETWORK_NAME" > /dev/null; then
        echo
        echo "Network $NETWORK_NAME does not exist, please create it"
        exit 1
    fi
    for (( i=1; i<=NODE_COUNT; i++ )); do
        create_vm "$i"
    done
}

function cleanup {
    local vms
    vms=$(virsh --connect=qemu:///system list --all --name | grep "$NODE_NAME_PREFIX")
    for vm in $vms; do
        delete_vm "$vm"
    done
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        "--create")
            ACTION="CREATE";
        ;;
        "--cleanup")
            ACTION="CLEANUP";
        ;;
        "--num-nodes")
            [[ $2 =~ ^[0-9]+$ ]] || { echo "Invalid value --num-nodes must be a number"; usage; exit 1; }
            NODE_COUNT="$2";
            shift
        ;;
        *)
            echo "Unknown parameter passed: $1";
            usage
            exit 1
        ;;
    esac
    shift
done

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
