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
# expect that the gen-edpm-node-common.sh is in the same dir as the calling script
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source ${SCRIPTPATH}/gen-edpm-node-common.sh $@

if [ ! -f ${DISK_FILEPATH} ]; then
    if [ ! -f ${CRC_POOL}/${BASE_DISK_FILENAME} ]; then
        pushd ${CRC_POOL}
        curl -L -k ${EDPM_IMAGE_URL} -o ${BASE_DISK_FILENAME}
        popd
    fi
    qemu-img create -o backing_file=${CRC_POOL}/${BASE_DISK_FILENAME},backing_fmt=qcow2 -f qcow2 "${DISK_FILEPATH}" "${EDPM_COMPUTE_DISK_SIZE}G"
    if [[ ! -e /usr/bin/virt-customize ]]; then
        sudo dnf -y install /usr/bin/virt-customize
    fi
    virt-customize -a ${DISK_FILEPATH} \
        --root-password password:12345678 \
        --hostname ${EDPM_COMPUTE_NAME} \
        --firstboot ${OUTPUT_DIR}/${EDPM_COMPUTE_NAME}-firstboot.sh \
        --run-command "systemctl disable cloud-init cloud-config cloud-final cloud-init-local" \
        --run-command "echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/99-root-login.conf" \
        --run-command "mkdir -p /root/.ssh; chmod 0700 /root/.ssh" \
        --run-command "ssh-keygen -f /root/.ssh/id_rsa -N ''" \
        --ssh-inject root:string:"$(cat $SSH_PUBLIC_KEY)" \
        --no-network \
        --selinux-relabel || rm -f ${DISK_FILEPATH}
    if [ ! -f ${DISK_FILEPATH} ]; then
        exit 1
    fi
fi

if ! virsh domuuid ${EDPM_COMPUTE_NAME}; then
    virsh define "${OUTPUT_DIR}/${EDPM_COMPUTE_NAME}.xml"
else
    echo "${EDPM_COMPUTE_NAME} already defined in libvirt, not redefining."
fi
if [ "$(virsh domstate ${EDPM_COMPUTE_NAME})" != "running" ]; then
    virsh start ${EDPM_COMPUTE_NAME}
else
    echo "${EDPM_COMPUTE_NAME} already running."
fi
