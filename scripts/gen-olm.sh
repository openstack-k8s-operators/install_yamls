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

if [ -z "${OPERATOR_NAMESPACE}" ]; then
    echo "Please set OPERATOR_NAMESPACE"; exit 1
fi
if [ -z "${OPERATOR_NAME}" ]; then
    echo "Please set OPERATOR_NAME"; exit 1
fi
if [ -z "${IMAGE}" ]; then
    echo "Please set IMAGE"; exit 1
fi
if [ -z "${OPERATOR_DIR}" ]; then
    echo "Please set OPERATOR_DIR"; exit 1
fi

if [ ! -d ${OPERATOR_DIR} ]; then
    mkdir -p ${OPERATOR_DIR}
fi

OPERATOR_CHANNEL=${OPERATOR_CHANNEL:-"alpha"}
OPERATOR_SOURCE=${OPERATOR_SOURCE:-"${OPERATOR_NAME}-operator-index"}
OPERATOR_SOURCE_NAMESPACE=${OPERATOR_SOURCE_NAMESPACE:-"${OPERATOR_NAMESPACE}"}

echo OPERATOR_DIR ${OPERATOR_DIR}
echo OPERATOR_CHANNEL ${OPERATOR_CHANNEL}
echo OPERATOR_SOURCE ${OPERATOR_SOURCE}
echo OPERATOR_SOURCE_NAMESPACE ${OPERATOR_SOURCE_NAMESPACE}

# can share this for all the operators, won't get re-applied if it already exists
cat > ${OPERATOR_DIR}/operatorgroup.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openstack
  namespace: ${OPERATOR_NAMESPACE}
EOF_CAT

cat > ${OPERATOR_DIR}/catalogsource.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: $OPERATOR_NAME-operator-index
  namespace: ${OPERATOR_NAMESPACE}
spec:
  image: ${IMAGE}
  sourceType: grpc
EOF_CAT

cat > ${OPERATOR_DIR}/subscription.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${OPERATOR_NAME}-operator
  namespace: ${OPERATOR_NAMESPACE}
spec:
  name: ${OPERATOR_NAME}-operator
  channel: ${OPERATOR_CHANNEL}
  source: ${OPERATOR_SOURCE}
  sourceNamespace: ${OPERATOR_SOURCE_NAMESPACE}
EOF_CAT
