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

if [ -z "${NET_PREFIX}" ]; then
    echo "Please set NET_PREFIX"; exit 1
fi

echo DEPLOY_DIR ${DEPLOY_DIR}
echo INTERFACE ${INTERFACE}
echo NET_PREFIX ${NET_PREFIX}

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
        "range": "${NET_PREFIX}.0/24",
        "range_start": "${NET_PREFIX}.30",
        "range_end": "${NET_PREFIX}.70"
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
      "master": "${INTERFACE}.20",
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
      "master": "${INTERFACE}.21",
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
      "master": "${INTERFACE}.22",
      "ipam": {
        "type": "whereabouts",
        "range": "172.19.0.0/24",
        "range_start": "172.19.0.30",
        "range_end": "172.19.0.70"
      }
    }
EOF_CAT
