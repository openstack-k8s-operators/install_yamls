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

if [ -z "${PEER_ASN}" ]; then
    echo "Please set PEER_ASN"; exit 1
fi

if [ -z "${LEAF_1}" ]; then
    echo "Please set LEAF_1"; exit 1
fi

if [ -z "${LEAF_2}" ]; then
    echo "Please set LEAF_2"; exit 1
fi

if [ -z "${SOURCE_IP}" ]; then
    echo "Please set SOURCE_IP"; exit 1
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
  peerASN: ${PEER_ASN}
  peerAddress: ${LEAF_1}
  password: f00barZ
  routerID: ${SOURCE_IP}
---
apiVersion: metallb.io/v1beta2
kind: BGPPeer
metadata:
  name: bgp-peer-2
  namespace: metallb-system
spec:
  myASN: ${ASN}
  peerASN: ${PEER_ASN}
  peerAddress: ${LEAF_2}
  password: f00barZ
  routerID: ${SOURCE_IP}
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
cat > ${DEPLOY_DIR}/bgpextras.yaml << EOF_CAT
---
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: bgpextras
data:
  extras: |
    router bgp ${ASN}
      network ${SOURCE_IP}/32
      neighbor ${LEAF_1} allowas-in origin
      neighbor ${LEAF_2} allowas-in origin

    ! ip prefix-list osp permit 172.16.0.0/16 le 32
    route-map ${LEAF_1}-in permit 20
      ! match ip address prefix-list osp
      set src ${SOURCE_IP}
    route-map ${LEAF_2}-in permit 20
      ! match ip address prefix-list osp
      set src ${SOURCE_IP}
    ip protocol bgp route-map ${LEAF_1}-in
    ip protocol bgp route-map ${LEAF_2}-in

    ip prefix-list ocp-lo permit ${SOURCE_IP}/32
    route-map ${LEAF_1}-out permit 1
      match ip address prefix-list ocp-lo
    route-map ${LEAF_2}-out permit 1
      match ip address prefix-list ocp-lo
EOF_CAT
