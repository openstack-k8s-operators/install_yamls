#!/bin/bash
#
# Copyright 2023 Red Hat Inc.
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
OUTPUT_DIR=${OUTPUT_DIR:-"../../out/edpm"}
SSH_KEY_FILE=${SSH_KEY_FILE:-"ansibleee-ssh-key-id_rsa"}
EDPM_INVENTORY_SECRET=${EDPM_INVENTORY_SECRET:-"dataplanenodeset-openstack-edpm"}
EDPM_PLAYBOOK=${EDPM_PLAYBOOK:-"osp.edpm.download_cache"}
EDPM_ANSIBLE_PATH=${EDPM_ANSIBLE_PATH:-"../../out/edpm-ansible"}

pushd ${SCRIPTPATH}

if [ ! -d ${EDPM_ANSIBLE_PATH} ]; then
    git clone https://github.com/openstack-k8s-operators/edpm-ansible.git ${EDPM_ANSIBLE_PATH}
    echo "${EDPM_ANSIBLE_PATH} will be mounted into ${OPENSTACK_RUNNER_IMG}"
fi

pushd ${OUTPUT_DIR}

if oc get secret ${EDPM_INVENTORY_SECRET} -n ${NAMESPACE} 2>&1 1>/dev/null; then
    oc get secret ${EDPM_INVENTORY_SECRET} -n ${NAMESPACE} -o json | jq '.data | map_values(@base64d)' | jq -r .inventory > inventory
else
    echo "Secret ${EDPM_INVENTORY_SECRET} not found! Please use EDPM_INVENTORY_SECRET to provide the correct secret name"
    exit 1
fi

podman run --rm -ti \
            -e "ANSIBLE_ENABLE_TASK_DEBUGGER=true" \
            -e "ANSIBLE_FORCE_COLOR=true" \
            -e "ANSIBLE_VERBOSITY=2" \
            -e "ANSIBLE_CALLBACKS_ENABLED=profile_tasks" \
            -e "ANSIBLE_SSH_ARGS=-C -o ControlMaster=auto -o ControlPersist=80s" \
            --volume "${EDPM_ANSIBLE_PATH}":/usr/share/ansible/collections/ansible_collections/osp/edpm:Z \
            --volume "$(pwd)/inventory":/runner/inventory/hosts:Z \
            --volume "$(pwd)/ansibleee-ssh-key-id_rsa":/runner/env/ssh_key:Z \
            ${OPENSTACK_RUNNER_IMG} \
            bash -c "ansible-runner run /runner -p ${EDPM_PLAYBOOK}"
rm inventory
