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
export NODE_COUNT=${NODE_COUNT:-2}
export DEPLOY_DIR=${DEPLOY_DIR:-"../out/edpm"}

OPERATOR_DIR=${OPERATOR_DIR:-../out/operator}
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
NODE_NAME_PREFIX=${NODE_NAME_PREFIX:-"crc-bmaas"}
NETWORK_NAME=${NETWORK_NAME:-"crc-bmaas"}
BMH_CR_FILE=${BMH_CR_FILE:-bmh_deploy.yaml}

# Remove service creation after dataplane-operator has been bumped
DATAPLANE_REPO=${DATAPLANE_REPO:-https://github.com/openstack-k8s-operators/dataplane-operator.git}
DATAPLNE_BRANCH=${DATAPLANE_BRANCH:-main}

mkdir -p ${OPERATOR_DIR}
rm -Rf ${OPERATOR_DIR}/dataplane-operator || true
pushd ${OPERATOR_DIR} && git clone $(if [ ${DATAPLANE_BRANCH} ]; then echo -b ${DATAPLANE_BRANCH}; fi) \
    ${DATAPLANE_REPO} "dataplane-operator" && popd
oc apply -f ${OPERATOR_DIR}/dataplane-operator/config/services

mkdir -p ${DEPLOY_DIR}
NODE_INDEX=0
while IFS= read -r instance; do
    export uuid_${NODE_INDEX}="${instance% *}"
    name="${instance#* }"
    export mac_address_${NODE_INDEX}=$(virsh --connect=qemu:///system domiflist "$name" | grep "${NETWORK_NAME}" | awk '{print $5}')
    echo ${mac_address_0}
    NODE_INDEX=$((NODE_INDEX+1))
done <<< "$(virsh --connect=qemu:///system list --all --uuid --name | grep "${NODE_NAME_PREFIX}")"

for (( i=0; i<${NODE_COUNT}; i++ )); do
    mac_var=mac_address_${i}
    uuid_var=uuid_${i}
    cat <<EOF >>${DEPLOY_DIR}/${BMH_CR_FILE}
---
# This is the secret with the BMC credentials (Redfish in this case).
apiVersion: v1
kind: Secret
metadata:
  name: node-${i}-bmc-secret
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: crc-bmaas-${i}
  annotations:
    inspect.metal3.io: disabled
  labels:
    app: openstack
spec:
  bmc:
    address: redfish+http://sushy-emulator.apps-crc.testing/redfish/v1/Systems/${!uuid_var}
    credentialsName: node-${i}-bmc-secret
  bootMACAddress: ${!mac_var}
  bootMode: UEFI
  online: false
  rootDeviceHints:
    deviceName: /dev/vda
EOF
done

/bin/bash ${SCRIPTPATH}/gen-edpm-bmaas-kustomize.sh
/bin/bash ../scripts/operator-deploy-resources.sh
