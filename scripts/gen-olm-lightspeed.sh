#!/bin/bash
#
# Copyright 2026 Red Hat Inc.
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

for var in OPERATOR_DIR NAMESPACE IMAGE CATALOG CHANNEL; do
    if [ -z "${!var}" ]; then
        echo "Please set ${var}"; exit 1
    fi
done

if [ ! -d ${OPERATOR_DIR} ]; then
    mkdir -p ${OPERATOR_DIR}
fi

echo OPERATOR_DIR ${OPERATOR_DIR}

cat > ${OPERATOR_DIR}/catalogsource.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${CATALOG}
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ${IMAGE}
  displayName: OpenStack Lightspeed Operator
  publisher: Red Hat
EOF_CAT

cat > ${OPERATOR_DIR}/operatorgroup.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: lightspeed-operator-group
  namespace: ${NAMESPACE}
spec:
  targetNamespaces:
  - ${NAMESPACE}
EOF_CAT

cat > ${OPERATOR_DIR}/subscription.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openstack-lightspeed-operator
  namespace: ${NAMESPACE}
spec:
  channel: ${CHANNEL}
  installPlanApproval: Automatic
  name: openstack-lightspeed-operator
  source: ${CATALOG}
  sourceNamespace: openshift-marketplace
EOF_CAT
