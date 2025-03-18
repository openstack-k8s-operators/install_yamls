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

function check_var_set {
    if [[ ! -v $1 ]]; then
        echo "Please set $1"; exit 1
    fi
}

STATE=$1

check_var_set DEPLOY_DIR

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

check_var_set WORKERS

echo DEPLOY_DIR ${DEPLOY_DIR}
echo WORKERS ${WORKERS}

for WORKER in ${WORKERS}; do
  cat > ${DEPLOY_DIR}/${WORKER}_nncp_dns.yaml <<EOF_CAT
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  labels:
    osp/interface: nncp-dns
  name: nncp-dns-${WORKER}
spec:
  desiredState:
    dns-resolver:
      config:
        search: []
        server:
        - ${DNS_SERVER}
EOF_CAT

done
