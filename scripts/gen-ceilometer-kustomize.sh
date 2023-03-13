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

if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

if [ -z "$SECRET" ]; then
    echo "Please set SECRET"; exit 1
fi

if [ -z "$DEPLOY_DIR" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ -z "$CENTRAL_IMAGE" ]; then
    echo "Please set CENTRAL_IMAGE"; exit 1
fi

if [ -z "$NOTIFICATION_IMAGE" ]; then
    echo "Please set NOTIFICATION_IMAGE"; exit 1
fi

if [ -z "$SG_CORE_IMAGE" ]; then
    echo "Please set SG_CORE_IMAGE"; exit 1
fi

NAME=${KIND,,}

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

pushd ${DEPLOY_DIR}

cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
namespace: ${NAMESPACE}
patches:
- target:
    kind: Ceilometer
  patch: |-
    - op: replace
      path: /spec/secret
      value: ${SECRET}
    - op: replace
      path: /spec/storageClass
      value: ${STORAGE_CLASS}
EOF
if [ "$CENTRAL_IMAGE" != "unused" ]; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/centralImage
      value: ${CENTRAL_IMAGE}
EOF
fi
if [ "$NOTIFICATION_IMAGE" != "unused" ]; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/notificationImage
      value: ${NOTIFICATION_IMAGE}
EOF
fi
if [ "$SG_CORE_IMAGE" != "unused" ]; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/sgCoreImage
      value: ${SG_CORE_IMAGE}
EOF
fi

kustomization_add_resources

popd
