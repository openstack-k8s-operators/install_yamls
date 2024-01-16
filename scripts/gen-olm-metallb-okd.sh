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

if [ ! -d ${OPERATOR_DIR}/patches ]; then
    mkdir -p ${OPERATOR_DIR}/patches
fi

if [ -z "${DEPLOY_DIR}" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

echo OPERATOR_DIR ${OPERATOR_DIR}
echo DEPLOY_DIR ${DEPLOY_DIR}

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
  channel: beta
  name: metallb-operator
  source: operatorhubio-catalog
  sourceNamespace: openshift-marketplace
EOF_CAT

cat > ${OPERATOR_DIR}/patches/patch-deployment-controller-manager.yaml <<EOF_CAT
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metallb-operator-controller-manager
  namespace: metallb-system
spec:
  template:
    spec:
      containers:
      - name: manager
        env:
        - name: DEPLOY_SERVICEMONITORS
          value: "true"
        - name: METALLB_BGP_TYPE
          value: "frr"
        - name: FRR_IMAGE
          value: quay.io/frrouting/frr:8.4.2
EOF_CAT

cat > ${OPERATOR_DIR}/patches/patch-deployment-webhook-server.yaml <<EOF_CAT
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metallb-operator-webhook-server
  namespace: metallb-system
spec:
  template:
    spec:
      containers:
      - name: webhook-server
        env:
        - name: DEPLOY_SERVICEMONITORS
          value: "true"
        - name: METALLB_BGP_TYPE
          value: "frr"
EOF_CAT

cat > ${OPERATOR_DIR}/patches/privileged-role-binding.yaml <<EOF_CAT
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:openshift:scc:privileged
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:openshift:scc:privileged
subjects:
- kind: ServiceAccount
  name: controller
  namespace: metallb-system
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
