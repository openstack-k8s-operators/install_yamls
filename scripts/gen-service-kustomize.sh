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

if [ -n "$BGP" ]; then
    cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/networks/0
      value:
          name: BgpNet1
          dnsDomain: bgpnet1.example.com
          subnets:
          - name: subnet1
            allocationRanges:
            - end: 100.65.1.6
              start: 100.65.1.5
            cidr: 100.65.1.4/30
            gateway: 100.65.1.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.65.1.5
          - name: subnet2
            allocationRanges:
            - end: 100.65.2.6
              start: 100.65.2.5
            cidr: 100.65.2.4/30
            gateway: 100.65.2.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.65.2.5
          - name: subnet3
            allocationRanges:
            - end: 100.65.3.6
              start: 100.65.3.5
            cidr: 100.65.3.4/30
            gateway: 100.65.3.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.65.3.5
          - name: subnet4
            allocationRanges:
            - end: 100.65.4.6
              start: 100.65.4.5
            cidr: 100.65.4.4/30
            gateway: 100.65.4.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.65.4.5
    - op: add
      path: /spec/networks/1
      value:
          name: BgpNet2
          dnsDomain: bgpnet2.example.com
          subnets:
          - name: subnet1
            allocationRanges:
            - end: 100.64.1.6
              start: 100.64.1.5
            cidr: 100.64.1.4/30
            gateway: 100.64.1.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.64.1.5
          - name: subnet2
            allocationRanges:
            - end: 100.64.2.6
              start: 100.64.2.5
            cidr: 100.64.2.4/30
            gateway: 100.64.2.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.64.2.5
          - name: subnet3
            allocationRanges:
            - end: 100.64.3.6
              start: 100.64.3.5
            cidr: 100.64.3.4/30
            gateway: 100.64.3.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.64.3.5
          - name: subnet4
            allocationRanges:
            - end: 100.64.4.6
              start: 100.64.4.5
            cidr: 100.64.4.4/30
            gateway: 100.64.4.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.64.4.5
    - op: add
      path: /spec/networks/2
      value:
          name: BgpMainNet
          dnsDomain: bgpmainnet.example.com
          subnets:
          - name: subnet1
            cidr: 172.30.1.0/28
            allocationRanges:
            - end: 172.30.1.14
              start: 172.30.1.2
          - name: subnet2
            cidr: 172.30.2.0/28
            allocationRanges:
            - end: 172.30.2.14
              start: 172.30.2.2
          - name: subnet3
            cidr: 172.30.3.0/28
            allocationRanges:
            - end: 172.30.3.14
              start: 172.30.3.2
          - name: subnet4
            cidr: 172.30.4.0/28
            allocationRanges:
            - end: 172.30.4.14
              start: 172.30.4.2
    - op: add
      path: /spec/networks/3
      value:
          name: BgpMainNet6
          dnsDomain: bgpmainnet6.example.com
          subnets:
          - name: subnet1
            cidr: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0010/124
            allocationRanges:
            - end: f00d:f00d:f00d:f00d:f00d:f00d:f00d:001e
              start: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0012
          - name: subnet2
            cidr: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0020/124
            allocationRanges:
            - end: f00d:f00d:f00d:f00d:f00d:f00d:f00d:002e
              start: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0022
          - name: subnet3
            cidr: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0030/124
            allocationRanges:
            - end: f00d:f00d:f00d:f00d:f00d:f00d:f00d:003e
              start: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0032
          - name: subnet4
            cidr: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0040/124
            allocationRanges:
            - end: f00d:f00d:f00d:f00d:f00d:f00d:f00d:004e
              start: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0042
EOF
fi

kustomization_add_resources

popd
