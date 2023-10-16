#!/bin/bash
# set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit 1
fi

DEFAULT_NETWORK_NAME=${NETWORK_NAME:-"crc-bmaas"}
NETWORK_NAME=${NETWORK_NAME:-"$DEFAULT_NETWORK_NAME"}

function usage {
    echo
    echo "options:"
    echo "  --create        Create barametal NetworkAttachmentDefinition"
    echo "  --cleanup       Delete barametal NetworkAttachmentDefinition"
    echo
}

MY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$MY_TMP_DIR"' EXIT

function create {
    local temp_file
    temp_file=$(mktemp -p "$MY_TMP_DIR")
    # TODO: Make address range configurable.
    cat << EOF > "$temp_file"
---
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: baremetal
  namespace: openstack
spec:
  config: |-
    {
      "cniVersion": "0.3.1",
      "name": "baremetal",
      "type": "macvlan",
      "master": "$NETWORK_NAME",
      "ipam": {
        "type": "whereabouts",
        "range": "172.20.1.0/24",
        "exclude": [
          "172.20.1.1/32",
          "172.20.1.64/26",
          "172.20.1.128/25"
        ]
      }
    }
EOF
    # cat "$temp_file"
    oc apply -f "$temp_file"
}

function cleanup {
    oc delete -n openstack network-attachment-definitions.k8s.cni.cncf.io/baremetal --wait=true --ignore-not-found
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
