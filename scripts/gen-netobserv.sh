#!/bin/bash
#
# Copyright 2024 Red Hat Inc.
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

if [ -z "${DEPLOY_DIR}" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

if [ -z "${NAMESPACE}" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

echo DEPLOY_DIR ${DEPLOY_DIR}
echo NAMESPACE ${NAMESPACE}

cat > ${DEPLOY_DIR}/flowcollector.yaml <<EOF_CAT
---
apiVersion: flows.netobserv.io/v1beta2
kind: FlowCollector
metadata:
  name: cluster
spec:
  agent:
    ebpf:
      sampling: 500
      privileged: true
      features:
        - PacketDrop
        - DNSTracking
  deploymentModel: Direct
  kafka:
    sasl:
      type: Disabled
    tls:
      enable: false
      insecureSkipVerify: false
  loki:
    enable: true
    mode: LokiStack
    lokiStack:
      name: loki
  namespace: ${NAMESPACE}
EOF_CAT
