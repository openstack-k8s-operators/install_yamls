#!/bin/bash
set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit 1
fi

if ! which virt-install > /dev/null; then
    echo
    echo "virt-install not found"
    exit 1
fi

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
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
CONSOLE_LOG_DIR=${CONSOLE_LOG_DIR:-/var/log/bmaas_console_logs}
CLEANUP_DELETE_ARCHIVED_LOGS=${CLEANUP_DELETE_ARCHIVED_LOGS:-"false"}
LIBVIRT_HOOKS_PATH=${LIBVIRT_HOOKS_PATH:-/etc/libvirt/hooks/qemu.d}

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

function create_libvirt_logging {
    # Make sure the log directory exists
    sudo mkdir -p "$CONSOLE_LOG_DIR"
    # Set selinux context type to "virt_log_t"
    sudo chcon -t virt_log_t "$CONSOLE_LOG_DIR"
    echo "This directory contains the serial console log files from the virtual BMaaS
bare-metal nodes. The *_console_* log files are the original log files and
include ANSI control codes which can make the output difficult to read. The
*_no_ansi_* log files have had ANSI control codes removed from the file and are
easier to read.

On some occasions there won't be a corresponding *_no_ansi_* log file. You may
see a log file without a date/time in the file name. In that case you can
display the logfile in your console by doing:
    $ curl URL_TO_LOGFILE

This will have your terminal process the ANSI escape codes.

Another option, if you have the 'pv' executable installed, is to simulate a
low-speed connection.  In this example simulate a 300 Bytes/second connection.
    $ curl URL_TO_LOGFILE | pv -q -L 300

This can allow you to see some of the content before the screen is cleared by
an ANSI escape sequence.
" | sudo tee ${CONSOLE_LOG_DIR}/README


    # Make sure the libvirt hooks directory exist
    sudo mkdir -p $LIBVIRT_HOOKS_PATH
    # Copy the qemu hook to the right directory
    if ! sudo test -f "$LIBVIRT_HOOKS_PATH/10-logrotate.py"; then
        sudo cp -v "$SCRIPTPATH/files/logrotate_hook.py" "$LIBVIRT_HOOKS_PATH/10-logrotate.py"
    fi
    sudo chmod -v +x $LIBVIRT_HOOKS_PATH/10-logrotate.py
    sudo sed -e "s|%LOG_DIR%|$CONSOLE_LOG_DIR|g;" -i "$LIBVIRT_HOOKS_PATH/10-logrotate.py"
    if sudo systemctl is-enabled libvirtd.service; then
        sudo systemctl restart libvirtd.service
    elif sudo systemctl is-enabled virtqemud.service; then
        sudo systemctl restart virtqemud.service
    fi
}

function cleanup_libvirt_logging {
    if [ $CLEANUP_DELETE_ARCHIVED_LOGS = "true" ]; then
        if [ -n $CONSOLE_LOG_DIR ] && [ -d $CONSOLE_LOG_DIR ]; then
            sudo rm -f $CONSOLE_LOG_DIR/*_console.log
            sudo rm -f $CONSOLE_LOG_DIR/*_console_*.log
            sudo rm -f $CONSOLE_LOG_DIR/*_no_ansi_*.log
        fi
    fi
    if sudo test -f "$LIBVIRT_HOOKS_PATH/10-logrotate.py"; then
        sudo chmod -v -x $LIBVIRT_HOOKS_PATH/10-logrotate.py
    fi
    if sudo systemctl is-enabled libvirtd.service; then
        sudo systemctl restart libvirtd.service
    elif sudo systemctl is-enabled virtqemud.service; then
        sudo systemctl restart virtqemud.service
    fi
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
        --serial file,path="${CONSOLE_LOG_DIR}/${name}_console.log" \
        --rng /dev/urandom,rate.period=100,rate.bytes=1024 \
        --print-xml \
        > "$temp_file"
    cat $temp_file
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
    create_libvirt_logging
    create
elif [ "$ACTION" == "CLEANUP" ]; then
    cleanup
    cleanup_libvirt_logging
fi
