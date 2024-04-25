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

if [ -z "${NMSTATE_VERSION}" ]; then
    export NMSTATE_VERSION=v0.81.0
fi

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

echo OPERATOR_DIR ${OPERATOR_DIR}
echo DEPLOY_DIR ${DEPLOY_DIR}

for file in nmstate.io_nmstates.yaml service_account.yaml role.yaml role_binding.yaml operator.yaml; do
    curl -L -o ${OPERATOR_DIR}/$file https://github.com/nmstate/kubernetes-nmstate/releases/download/${NMSTATE_VERSION}/$file
    sed -i -e 's/\(^ *namespace: \).*/\1openshift-nmstate/g' ${OPERATOR_DIR}/$file
done

sed -i -e 's/\(^ *value: \)nmstate/\1openshift-nmstate/g' ${OPERATOR_DIR}/operator.yaml


cat > ${DEPLOY_DIR}/deploy_operator.yaml <<EOF_CAT
apiVersion: nmstate.io/v1
kind: NMState
metadata:
  name: nmstate
EOF_CAT
