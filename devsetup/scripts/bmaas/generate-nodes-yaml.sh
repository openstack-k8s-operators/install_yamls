#!/bin/bash
set -x

NODE_NAME_PREFIX=${NODE_NAME_PREFIX:-"crc-bmaas"}
INGRESS_DOMAIN=$(oc get ingresses.config/cluster -o jsonpath={.spec.domain})
REDFISH_USERNAME=${REDFISH_USERNAME:-"admin"}
REDFISH_PASSOWRD=${REDFISH_PASSOWRD:-"password"}
NETWORK_NAME=${NETWORK_NAME:-"crc-bmaas"}

function echo_nodes_yaml {
    local uuid
    local name
    local instance
    local mac_address
    echo "---"
    echo "nodes:"
    while IFS= read -r instance; do
        uuid="${instance% *}"
        name="${instance#* }"
        mac_address=$(virsh --connect=qemu:///system domiflist "$name" | grep "${NETWORK_NAME}" | awk '{print $5}')
        echo "- name: ${name}"
        echo "  driver: redfish"
        echo "  driver_info:"
        echo "    redfish_address: http://sushy-emulator.${INGRESS_DOMAIN}"
        echo "    redfish_system_id: /redfish/v1/Systems/${uuid}"
        echo "    redfish_username: ${REDFISH_USERNAME}"
        echo "    redfish_password: ${REDFISH_PASSOWRD}"
        echo "  ports:"
        echo "  - address: \"$mac_address\""
    done <<< "$(virsh --connect=qemu:///system list --all --uuid --name | grep "${NODE_NAME_PREFIX}")"
}

echo_nodes_yaml
