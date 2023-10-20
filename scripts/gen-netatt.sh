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

if [ -z "${DEPLOY_DIR}" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

if [ -z "${INTERFACE}" ]; then
    echo "Please set INTERFACE"; exit 1
fi

if [ -z "${VLAN_START}" ]; then
    echo "Please set VLAN_START"; exit 1
fi

if [ -z "${VLAN_STEP}" ]; then
    echo "Please set VLAN_STEP"; exit 1
fi

echo DEPLOY_DIR ${DEPLOY_DIR}
echo INTERFACE ${INTERFACE}
echo VLAN_START ${VLAN_START}
echo VLAN_STEP ${VLAN_STEP}

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
      "master": "${INTERFACE}.${VLAN_START}",
      "ipam": {
        "type": "whereabouts",
        "range": "172.17.0.0/24",
        "range_start": "172.17.0.30",
        "range_end": "172.17.0.70"
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
      "master": "${INTERFACE}.$((${VLAN_START}+${VLAN_STEP}))",
      "ipam": {
        "type": "whereabouts",
        "range": "172.18.0.0/24",
        "range_start": "172.18.0.30",
        "range_end": "172.18.0.70"
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
      "master": "${INTERFACE}.$((${VLAN_START}+$((${VLAN_STEP}*2))))",
      "ipam": {
        "type": "whereabouts",
        "range": "172.19.0.0/24",
        "range_start": "172.19.0.30",
        "range_end": "172.19.0.70"
      }
    }
EOF_CAT

if [ -n "$INTERFACE_BGP_1" ]; then
    cat > ${DEPLOY_DIR}/bgpnet1.yaml <<EOF_CAT
    apiVersion: k8s.cni.cncf.io/v1
    kind: NetworkAttachmentDefinition
    metadata:
      labels:
        osp/net: bgpnet1
      name: bgpnet1
      namespace: openstack
    spec:
      config: |
        {
          "cniVersion": "0.3.1",
          "name": "bgpnet1",
          "type": "interface",
          "master": "${INTERFACE_BGP_1}",
          "ipam": {
            "type": "whereabouts",
            "range": "100.65.4.0/30",
            "range_start": "100.65.4.1",
            "range_end": "100.65.4.2"
          }
        }
EOF_CAT
fi

if [ -n "$INTERFACE_BGP_2" ]; then
    cat > ${DEPLOY_DIR}/bgpnet2.yaml <<EOF_CAT
    apiVersion: k8s.cni.cncf.io/v1
    kind: NetworkAttachmentDefinition
    metadata:
      labels:
        osp/net: bgpnet2
      name: bgpnet2
      namespace: openstack
    spec:
      config: |
        {
          "cniVersion": "0.3.1",
          "name": "bgpnet2",
          "type": "interface",
          "master": "${INTERFACE_BGP_2}",
          "ipam": {
            "type": "whereabouts",
            "range": "100.64.4.0/30",
            "range_start": "100.64.4.1",
            "range_end": "100.64.4.2"
          }
        }
EOF_CAT
fi
