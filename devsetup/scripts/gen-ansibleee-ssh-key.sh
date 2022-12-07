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
OUTPUT_DIR=${OUTPUT_DIR:-"../out/edpm"}

if [ ! -d ${OUTPUT_DIR} ]; then
      mkdir -p ${OUTPUT_DIR}
fi

pushd ${OUTPUT_DIR}

if oc get secret ansibleee-ssh-key-secret 2>&1 1>/dev/null; then
    echo "Secret ansibleee-ssh-key-secret already exists."
    echo "Delete it first to recreate:"
    echo "oc delete secret ansibleee-ssh-key-secret"
    exit 0
fi

if [ ! -f ansibleee-ssh-key-id_rsa ]; then
    ssh-keygen -f ansibleee-ssh-key-id_rsa -N ""
fi

cat <<EOF >ansibleee-ssh-key-secret.yaml
apiVersion: v1
kind: Secret
namespace: ${NAMESPACE}
metadata:
    name: ansibleee-ssh-key-secret
data:
    public_ssh_key: |
$(cat ansibleee-ssh-key-id_rsa.pub | base64 | sed 's/^/        /')
    private_ssh_key: |
$(cat ansibleee-ssh-key-id_rsa | base64 | sed 's/^/        /')
EOF

oc create -f ansibleee-ssh-key-secret.yaml

popd
