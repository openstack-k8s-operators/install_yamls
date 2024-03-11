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
set -ex

function usage {
    echo
    echo "options:"
    echo "  --create     Create sushy-emulator backed baremetal hosts"
    echo "  --cleanup    Cleanup sushy-emulator backed baremetal hosts"
    echo
}

export NODE_COUNT=${NODE_COUNT:-2}
export DEPLOY_DIR=${DEPLOY_DIR:-"../out/edpm"}

OPERATOR_DIR=${OPERATOR_DIR:-../out/operator}
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
NODE_NAME_PREFIX=${BMAAS_INSTANCE_NAME_PREFIX=:-"edpm-compute"}
NETWORK_NAME=${BMAAS_NETWORK_NAME:-"default"}
BMH_CR_FILE=${BMH_CR_FILE:-bmh_deploy.yaml}

function create {
    mkdir -p ${DEPLOY_DIR}
    pushd ${DEPLOY_DIR}
    NODE_INDEX=0
    while IFS= read -r instance; do
        export uuid_${NODE_INDEX}="${instance% *}"
        name="${instance#* }"
        export mac_address_${NODE_INDEX}=$(virsh --connect=qemu:///system domiflist "$name" | grep "${NETWORK_NAME}" | awk '{print $5}')
        echo ${mac_address_0}
        NODE_INDEX=$((NODE_INDEX+1))
    done <<< "$(virsh --connect=qemu:///system list --all --uuid --name | grep "${NODE_NAME_PREFIX}")"

    rm ${BMH_CR_FILE} || true
    for (( i=0; i<${NODE_COUNT}; i++ )); do
        mac_var=mac_address_${i}
        uuid_var=uuid_${i}
        cat <<EOF >>${BMH_CR_FILE}
---
# This is the secret with the BMC credentials (Redfish in this case).
apiVersion: v1
kind: Secret
metadata:
  name: node-${i}-bmc-secret
  namespace: ${NAMESPACE}
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: edpm-compute-${i}
  namespace: ${NAMESPACE}
  annotations:
    inspect.metal3.io: disabled
  labels:
    app: openstack
spec:
  bmc:
    address: redfish-virtualmedia+http://sushy-emulator.apps-crc.testing/redfish/v1/Systems/${!uuid_var}
    credentialsName: node-${i}-bmc-secret
  bootMACAddress: ${!mac_var}
  bootMode: UEFI
  online: false
  rootDeviceHints:
    deviceName: /dev/vda
EOF
    done
    cat <<EOF >kustomization.yaml

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${NAMESPACE}
resources:
  - ${BMH_CR_FILE}
EOF
    popd
    /bin/bash ../scripts/operator-deploy-resources.sh
}

function cleanup {
    while oc get bmh | grep -q -e "deprovisioning" -e "provisioned"; do
        sleep 5
    done || true
    oc delete --all -n bmh $NAMESPACE --ignore-not-found=true || true
}

case "$1" in
    "--create")
        create;
    ;;
    "--cleanup")
        cleanup;
    ;;
    *)
        echo >&2 "Invalid option: $*";
        usage;
        exit 1
    ;;
esac
