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

# expect that the common.sh is in the same dir as the calling script
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
. ${SCRIPTPATH}/common.sh --source-only

NAMESPACE=$1
KEYSTONE_ADMIN_PWD=$2
KEYSTONE_DB_PWD=$3

if [ -z "$NAMESPACE" ]; then
      echo "Please set NAMESPACE as ARG1"; exit 1
fi

if [ -z "$KEYSTONE_ADMIN_PWD" ]; then
      echo "Please set KEYSTONE_ADMIN_PWD as ARG2"; exit 1
fi

if [ -z "$KEYSTONE_DB_PWD" ]; then
      echo "Please set KEYSTONE_DB_PWD as ARG3"; exit 1
fi

CR_DIR=out/${NAMESPACE}/keystone/cr

if [ ! -d ${CR_DIR} ]; then
      mkdir -p ${CR_DIR}
fi

pushd ${CR_DIR}

cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
secretGenerator:
- name: keystone-secret
  literals:
  - AdminPassword=${KEYSTONE_ADMIN_PWD}
  - DatabasePassword=${KEYSTONE_DB_PWD}
generatorOptions:
  disableNameSuffixHash: true
  labels:
    type: keystone-secret
patches:
- patch: |-
    - op: replace
      path: /metadata/name
      value: keystoneapi
    - op: replace
      path: /metadata/namespace
      value: ${NAMESPACE}
    - op: replace
      path: /spec/containerImage
      value: quay.io/tripleotraincentos8/centos-binary-keystone:current-tripleo
    - op: replace
      path: /spec/secret
      value: keystone-secret
  target:
    kind: KeystoneAPI
EOF

kustomization_add_resources

popd
