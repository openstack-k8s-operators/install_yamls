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
MARIADB_ROOT_PASSWORD=$2

if [ -z "$NAMESPACE" ]; then
      echo "Please set NAMESPACE as ARG2"; exit 1
fi

if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
      echo "Please set DB_ROOT_PASSWORD as ARG3"; exit 1
fi

CR_DIR=out/${NAMESPACE}/mariadb/cr

if [ ! -d ${CR_DIR} ]; then
      mkdir -p ${CR_DIR}
fi

pushd ${CR_DIR}

cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
secretGenerator:
- name: mariadb-secret
  literals:
  - DbRootPassword=${MARIADB_ROOT_PASSWORD}
generatorOptions:
  disableNameSuffixHash: true
  labels:
    type: mariadb-secret
patches:
- patch: |-
    - op: replace
      path: /spec/containerImage
      value: quay.io/tripleotraincentos8/centos-binary-mariadb:current-tripleo
    - op: replace
      path: /spec/secret
      value: mariadb-secret
    - op: replace
      path: /metadata/namespace
      value: ${NAMESPACE}
  target:
    kind: MariaDB
EOF

kustomization_add_resources

popd
