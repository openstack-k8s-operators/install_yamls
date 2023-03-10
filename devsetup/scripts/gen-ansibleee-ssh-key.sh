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
NAMESPACE=${NAMESPACE:-"openstack"}
METADATA_NAME=${METADATA_NAME:-"dataplane-ansible-ssh-private-key-secret"}
OUTPUT_DIR=${OUTPUT_DIR:-"../../out/edpm"}
SSH_ALGORITHM=${SSH_ALGORITHM:-"rsa"}
SSH_KEY_FILE=${SSH_KEY_FILE:-"ansibleee-ssh-key-id_rsa"}
SSH_KEY_SIZE=${SSH_KEY_SIZE:-"4096"}

pushd ${SCRIPTPATH}

if [ ! -d ${OUTPUT_DIR} ]; then
    mkdir -p ${OUTPUT_DIR}
fi

pushd ${OUTPUT_DIR}

if oc get secret dataplane-ansible-ssh-private-key-secret 2>&1 1>/dev/null; then
    echo "Secret dataplane-ansible-ssh-private-key-secret already exists."
    echo "Delete it first to recreate:"
    echo "oc delete secret dataplane-ansible-ssh-private-key-secret"
    exit 0
fi

if [ ! -f ${SSH_KEY_FILE} ]; then
    ssh-keygen -f ${SSH_KEY_FILE} -N "" -t ${SSH_ALGORITHM} -b ${SSH_KEY_SIZE}
fi

cat <<EOF >namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
    name: ${NAMESPACE}
    labels:
      pod-security.kubernetes.io/enforce: privileged
      security.openshift.io/scc.podSecurityLabelSync: "false"
EOF

cat <<EOF >dataplane-ansible-ssh-private-key-secret.yaml
apiVersion: v1
kind: Secret
metadata:
    name: ${METADATA_NAME}
    namespace: ${NAMESPACE}
data:
    ssh-publickey: |
$(cat ${SSH_KEY_FILE}.pub | base64 | sed 's/^/        /')
    ssh-privatekey: |
$(cat ${SSH_KEY_FILE} | base64 | sed 's/^/        /')
EOF

oc apply -f namespace.yaml
oc apply -f dataplane-ansible-ssh-private-key-secret.yaml

popd
popd
