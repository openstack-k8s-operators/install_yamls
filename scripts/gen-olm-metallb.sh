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

if [ -z "${OPERATOR_DIR}" ]; then
    echo "Please set OPERATOR_DIR"; exit 1
fi

if [ ! -d ${OPERATOR_DIR} ]; then
    mkdir -p ${OPERATOR_DIR}
fi

if [ -z "${DEPLOY_DIR}" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

if [ -z "${INTERFACE}" ]; then
    echo "Please set INTERFACE"; exit 1
fi

if [ -z "${ASN}" ]; then
    echo "Please set ASN"; exit 1
fi

if [ -z "${LEAF_1}" ]; then
    echo "Please set LEAF_1"; exit 1
fi

if [ -z "${LEAF_2}" ]; then
    echo "Please set LEAF_2"; exit 1
fi

echo OPERATOR_DIR ${OPERATOR_DIR}
echo DEPLOY_DIR ${DEPLOY_DIR}
echo INTERFACE ${INTERFACE}

cat > ${OPERATOR_DIR}/operatorgroup.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: metallb-operator
  namespace: metallb-system
EOF_CAT

cat > ${OPERATOR_DIR}/subscription.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: metallb-operator-sub
  namespace: metallb-system
spec:
  channel: stable
  name: metallb-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF_CAT

cat > ${DEPLOY_DIR}/deploy_operator.yaml <<EOF_CAT
apiVersion: metallb.io/v1beta1
kind: MetalLB
metadata:
  name: metallb
  namespace: metallb-system
spec:
  logLevel: debug
  nodeSelector:
    node-role.kubernetes.io/worker: ""
EOF_CAT

cat > ${DEPLOY_DIR}/ipaddresspools.yaml <<EOF_CAT
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: ctlplane
spec:
  addresses:
  - ${CTLPLANE_METALLB_POOL}
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: internalapi
spec:
  addresses:
  - 172.17.0.80-172.17.0.90
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: storage
spec:
  addresses:
  - 172.18.0.80-172.18.0.90
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: tenant
spec:
  addresses:
  - 172.19.0.80-172.19.0.90
EOF_CAT

cat > ${DEPLOY_DIR}/l2advertisement.yaml <<EOF_CAT
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: ctlplane
  namespace: metallb-system
spec:
  ipAddressPools:
  - ctlplane
  interfaces:
  - ${INTERFACE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: internalapi
  namespace: metallb-system
spec:
  ipAddressPools:
  - internalapi
  interfaces:
  - ${INTERFACE}.20
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: storage
  namespace: metallb-system
spec:
  ipAddressPools:
  - storage
  interfaces:
  - ${INTERFACE}.21
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: tenant
  namespace: metallb-system
spec:
  ipAddressPools:
  - tenant
  interfaces:
  - ${INTERFACE}.22
EOF_CAT
cat > ${DEPLOY_DIR}/bgppeers.yaml <<EOF_CAT
---
apiVersion: metallb.io/v1beta2
kind: BGPPeer
metadata:
  name: bgp-peer
  namespace: metallb-system
spec:
  myASN: ${ASN}
  peerASN: ${ASN}
  peerAddress: ${LEAF_1}
  password: f00barZ
---
apiVersion: metallb.io/v1beta2
kind: BGPPeer
metadata:
  name: bgp-peer-2
  namespace: metallb-system
spec:
  myASN: ${ASN}
  peerASN: ${ASN}
  peerAddress: ${LEAF_2}
  password: f00barZ
EOF_CAT
cat > ${DEPLOY_DIR}/bgpadvertisement.yaml <<EOF_CAT
---
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: bgpadvertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - ctlplane
  - internalapi
  - storage
  - tenant
  peers:
  - bgp-peer
  - bgp-peer-2
EOF_CAT
