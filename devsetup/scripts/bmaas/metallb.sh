#!/bin/bash
#
# Copyright 2023 Red Hat Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit 1
fi

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
NETWORK_NAME=${NETWORK_NAME:-"crc-bmaas"}
POOL_NAME=${POOL_NAME:-"baremetal"}
ADDRESS_POOL=${ADDRESS_POOL:-"172.20.1.64/26"}

function usage {
    echo
    echo "options:"
    echo "  --create        Create ipaddresspool and l2advertisement"
    echo "  --cleanup       Delete ipaddresspool and l2advertisement"
    echo
}

MY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$MY_TMP_DIR"' EXIT


function create_addresspool {
    cat > ${MY_TMP_DIR}/ipaddresspools.yaml <<EOF_CAT
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: ${POOL_NAME}
spec:
  addresses:
  - ${ADDRESS_POOL}
EOF_CAT

    oc apply -f ${MY_TMP_DIR}/ipaddresspools.yaml
}

function cleanup_addresspool {
    oc delete ipaddresspools.metallb.io ${POOL_NAME} -n metallb-system --wait=true || true
}

function create_l2advertisement {
    cat > ${MY_TMP_DIR}/l2advertisement.yaml <<EOF_CAT
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: ${POOL_NAME}
  namespace: metallb-system
spec:
  ipAddressPools:
  - ${POOL_NAME}
  interfaces:
  - ${NETWORK_NAME}
EOF_CAT

    oc apply -f ${MY_TMP_DIR}/l2advertisement.yaml
}

function cleanup_l2advertisement {
    oc delete l2advertisements.metallb.io ${POOL_NAME} -n metallb-system --wait=true || true
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
    create_addresspool
    create_l2advertisement
elif [ "$ACTION" == "CLEANUP" ]; then
    cleanup_l2advertisement
    cleanup_addresspool
fi
