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

curl -L https://github.com/metallb/metallb-operator/archive/refs/tags/v0.14.2.tar.gz | tar -xz --strip-components=1 -C ${OPERATOR_DIR}

cat > ${OPERATOR_DIR}/config/openshift/patch-deployment-webhook-server.yaml <<EOF_CAT
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
        image: quay.io/metallb/controller:v0.14.5
        env:
        - name: DEPLOY_SERVICEMONITORS
          value: "true"
        - name: METALLB_BGP_TYPE
          value: "frr"
EOF_CAT

patch ${OPERATOR_DIR}/config/openshift/kustomization.yaml <<EOF_PATCH
@@ -8,4 +8,5 @@
 patches:
 - path: patch-namespace.yaml
 - path: patch-deployment-controller-manager.yaml
+- path: patch-deployment-webhook-server.yaml
 namespace: metallb-system
EOF_PATCH

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
