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

if [ -z "$KIND" ]; then
    echo "Please set SERVICE"; exit 1
fi

if [ -z "$SECRET" ]; then
    echo "Please set SECRET"; exit 1
fi

if [ -z "$DEPLOY_DIR" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

IMAGE=${IMAGE:-unused}
IMAGE_PATH=${IMAGE_PATH:-containerImage}

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
    kind: ${KIND}
  patch: |-
    - op: replace
      path: /spec/secret
      value: ${SECRET}
    - op: replace
      path: /spec/storageClass
      value: ${STORAGE_CLASS}
EOF

IFS=',' read -ra IMAGES <<< "$IMAGE"
IFS=',' read -ra IMAGE_PATHS <<< "$IMAGE_PATH"

if [ ${#IMAGES[@]} != ${#IMAGE_PATHS[@]} ]; then
    echo "IMAGE and IMAGE_PATH should have the same length"; exit 1
fi

for (( i=0; i < ${#IMAGES[@]}; i++)); do
    SPEC_PATH=${IMAGE_PATHS[$i]}
    SPEC_VALUE=${IMAGES[$i]}

    if [ "${SPEC_VALUE}" != "unused" ]; then
        cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/${SPEC_PATH}
      value: ${SPEC_VALUE}
EOF
    fi
done

if [ -n "$NAME" ]; then
    cat <<EOF >>kustomization.yaml
    - op: replace
      path: /metadata/name
      value: ${NAME}
EOF
fi

kustomization_add_resources

popd
