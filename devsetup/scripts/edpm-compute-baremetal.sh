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

OPERATOR_DIR=${OPERATOR_DIR:-../out/operator}
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
NODE_NAME_PREFIX=${BMAAS_INSTANCE_NAME_PREFIX:-"edpm-compute"}
NODE_NAME_SUFFIX=${BMAAS_INSTANCE_NAME_SUFFIX:-"0"}
NETWORK_NAME=${BMAAS_NETWORK_NAME:-"default"}
BMH_CR_FILE=${BMH_CR_FILE:-bmh_deploy.yaml}
INGRESS_DOMAIN=$(oc get ingresses.config/cluster -o jsonpath={.spec.domain})

NODE_NAME_SUFFIX_PADDED=$(printf "%02d" "$NODE_NAME_SUFFIX")
NODE_NAME=${NODE_NAME:-"${NODE_NAME_PREFIX}-${NODE_NAME_SUFFIX_PADDED}"}

DEPLOY_DIR=${DEPLOY_DIR:-"../out/edpm"}
export DEPLOY_DIR=${DEPLOY_DIR}/${NODE_NAME}


function create {
    mkdir -p ${DEPLOY_DIR}
    pushd ${DEPLOY_DIR}

    export mac_address=$(virsh --connect=qemu:///system domiflist "${NODE_NAME}" | grep "${NETWORK_NAME}" | awk '{print $5}')
    export uuid=$(virsh --connect=qemu:///system dominfo "${NODE_NAME}" | grep "UUID" | awk '{print $2}')

    cat <<EOF >${BMH_CR_FILE}
---
# This is the secret with the BMC credentials (Redfish in this case).
apiVersion: v1
kind: Secret
metadata:
  name: node-${NODE_NAME_SUFFIX}-bmc-secret
  namespace: ${NAMESPACE}
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: ${NODE_NAME}
  namespace: ${NAMESPACE}
  annotations:
    inspect.metal3.io: disabled
  labels:
    app: openstack
spec:
  bmc:
    address: redfish-virtualmedia+http://sushy-emulator.${INGRESS_DOMAIN}/redfish/v1/Systems/${uuid}
    credentialsName: node-${NODE_NAME_SUFFIX}-bmc-secret
  bootMACAddress: ${mac_address}
  bootMode: UEFI
  online: false
  rootDeviceHints:
    deviceName: /dev/vda
EOF

    cat <<EOF >kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${NAMESPACE}
labels:
  - pairs:
      created-by: install_yamls
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
    oc delete bmh -n $NAMESPACE --ignore-not-found=true ${NODE_NAME_PREFIX}-${NODE_NAME_SUFFIX_PADDED} || true
    rm -rf ${DEPLOY_DIR}
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
