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

function check_var_setted () {
  if [[ ! -v $1 ]]; then
    echo "Please set $1"; exit 1
  fi
}

check_var_setted OPERATOR_DIR

if [ ! -d ${OPERATOR_DIR} ]; then
    mkdir -p ${OPERATOR_DIR}
fi

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
  - ${INTERNALAPI_NET}.${INTERNALAPI_IP_START}-${INTERNALAPI_NET}.${INTERNALAPI_IP_END}
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: storage
spec:
  addresses:
  - ${STORAGE_NET}.${STORAGE_IP_START}-${STORAGE_NET}.${STORAGE_IP_END}
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: tenant
spec:
  addresses:
  - ${TENANT_NET}.${TENANT_IP_START}-${TENANT_NET}.${TENANT_IP_END}
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
  - ${INTERFACE_DATA}.${INTERNALAPI_VLAN}
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
  - ${INTERFACE_MANAGEMENT}.${STORAGE_VLAN}
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
  - ${INTERFACE_MANAGEMENT}.${TENANT_VLAN}
EOF_CAT
