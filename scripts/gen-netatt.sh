#!/bin/bash
#
# Copyright 2022 Red Hat Inc.
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

function check_var_setted {
    if [[ ! -v $1 ]]; then
        echo "Please set $1"; exit 1
    fi
}

check_var_setted DEPLOY_DIR

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

check_var_setted INTERFACE
check_var_setted INTERFACE_DATA
check_var_setted INTERFACE_MANAGEMENT
check_var_setted INTERFACE_EXTERNAL
check_var_setted INTERNALAPI_VLAN
check_var_setted STORAGE_VLAN
check_var_setted TENANT_VLAN
check_var_setted INTERNALAPI_NET
check_var_setted STORAGE_NET
check_var_setted TENANT_NET
check_var_setted INTERNALAPI_IP_START
check_var_setted INTERNALAPI_IP_END
check_var_setted STORAGE_IP_START
check_var_setted STORAGE_IP_END
check_var_setted TENANT_IP_START
check_var_setted TENANT_IP_END

echo DEPLOY_DIR ${DEPLOY_DIR}
echo INTERFACE ${INTERFACE}
echo INTERFACE_DATA ${INTERFACE_DATA}
echo INTERFACE_MANAGEMENT ${INTERFACE_MANAGEMENT}
echo INTERFACE_EXTERNAL ${INTERFACE_EXTERNAL}
echo INTERNALAPI_VLAN ${INTERNALAPI_VLAN}
echo STORAGE_VLAN ${STORAGE_VLAN}
echo TENANT_VLAN ${TENANT_VLAN}
echo INTERNALAPI_NET ${INTERNALAPI_NET}
echo STORAGE_NET ${STORAGE_NET}
echo TENANT_NET ${TENANT_NET}
echo INTERNALAPI_IP_START ${INTERNALAPI_IP_START}
echo INTERNALAPI_IP_END ${INTERNALAPI_IP_END}
echo STORAGE_IP_START ${STORAGE_IP_START}
echo STORAGE_IP_END ${STORAGE_IP_END}
echo TENANT_IP_START ${TENANT_IP_START}
echo TENANT_IP_END ${TENANT_IP_END}

cat > ${DEPLOY_DIR}/ctlplane.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  labels:
    osp/net: ctlplane
  name: ctlplane
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "ctlplane",
      "type": "macvlan",
      "master": "${INTERFACE}",
      "ipam": {
        "type": "whereabouts",
        "range": "192.168.122.0/24",
        "range_start": "192.168.122.30",
        "range_end": "192.168.122.70"
      }
    }
EOF_CAT

cat > ${DEPLOY_DIR}/internalapi.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  labels:
    osp/net: internalapi
  name: internalapi
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "internalapi",
      "type": "macvlan",
      "master": "${INTERFACE_DATA}.${INTERNALAPI_VLAN}",
      "ipam": {
        "type": "whereabouts",
        "range": "${INTERNALAPI_NET}.0/24",
        "range_start": "${INTERNALAPI_NET}.${INTERNALAPI_IP_START}",
        "range_end": "${INTERNALAPI_NET}.${INTERNALAPI_IP_END}"
      }
    }
EOF_CAT

cat > ${DEPLOY_DIR}/storage.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  labels:
    osp/net: storage
  name: storage
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "storage",
      "type": "macvlan",
      "master": "${INTERFACE_MANAGEMENT}.${STORAGE_VLAN}",
      "ipam": {
        "type": "whereabouts",
        "range": "${STORAGE_NET}.0/24",
        "range_start": "${STORAGE_NET}.${STORAGE_IP_START}",
        "range_end": "${STORAGE_NET}.${STORAGE_IP_END}"
      }
    }
EOF_CAT

cat > ${DEPLOY_DIR}/tenant.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  labels:
    osp/net: tenant
  name: tenant
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "tenant",
      "type": "macvlan",
      "master": "${INTERFACE_MANAGEMENT}.${TENANT_VLAN}",
      "ipam": {
        "type": "whereabouts",
        "range": "${TENANT_NET}.0/24",
        "range_start": "${TENANT_NET}.${TENANT_IP_START}",
        "range_end": "${TENANT_NET}.${TENANT_IP_END}"
      }
    }
EOF_CAT
