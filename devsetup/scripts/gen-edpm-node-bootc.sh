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

EDPM_BOOTC_BUILDER_IMAGE=${EDPM_BOOTC_BUILDER_IMAGE:-"quay.io/centos-bootc/bootc-image-builder:latest"}
EDPM_BOOTC_REPO=${EDPM_BOOTC_REPO:-"quay.io/openstack-k8s-operators/edpm-bootc"}
EDPM_BOOTC_TAG=${EDPM_BOOTC_TAG:-"latest"}
EDPM_BOOTC_IMAGE=${EDPM_BOOTC_IMAGE:-"${EDPM_BOOTC_REPO}:${EDPM_BOOTC_TAG}"}
EDPM_BOOTC_CONFIG_TOML_FILE=${EDPM_BOOTC_CONFIG_TOML_FILE:-"${SCRIPTPATH}/../bootc/config.toml"}
EDPM_BOOTC_OUTPUT_DIR=${EDPM_BOOTC_OUTPUT_DIR:-"${OUTPUT_DIR}/bootc-image-builder/${EDPM_COMPUTE_NAME}"}

mkdir -p ${EDPM_BOOTC_OUTPUT_DIR}
export SSH_PUBLIC_KEY_CONTENTS="$(cat ${SSH_PUBLIC_KEY})"
envsubst < ${EDPM_BOOTC_CONFIG_TOML_FILE} > ${EDPM_BOOTC_OUTPUT_DIR}/config.toml

cat > ${EDPM_BOOTC_OUTPUT_DIR}/user-data <<EOF
#cloud-config
hostname: ${EDPM_COMPUTE_NAME}
fqdn: ${EDPM_COMPUTE_NAME}.${EDPM_COMPUTE_DOMAIN}
create_hostname_file: true
groups:
  - cloud-admin
users:
  - name: cloud-admin
    primary_group: cloud-admin
    ssh_authorized_keys:
      - ${SSH_PUBLIC_KEY_CONTENTS}
runcmd:
  - "echo 'cloud-admin     	ALL = (ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/cloud-admin"
  - "sudo chown root:root /etc/sudoers.d/cloud-admin"
  - "sudo chmod 0660 /etc/sudoers.d/cloud-admin"
  - "sudo loginctl enable-linger cloud-admin"
  - "sudo rm -f /etc/nvme/hostid /etc/nvme/hostnqn"
ssh_pwauth: true
ssh_authorized_keys:
  - ${SSH_PUBLIC_KEY_CONTENTS}
no_ssh_fingerprints: true
disable_root: false
EOF

cat > ${EDPM_BOOTC_OUTPUT_DIR}/meta-data <<EOF
instance-id: ${EDPM_COMPUTE_NAME}
hostname: ${EDPM_COMPUTE_NAME}
EOF

cat > ${EDPM_BOOTC_OUTPUT_DIR}/network-config <<EOF
network:
  version: 2
  ethernets:
    enp2s0:
      match:
        name: enp2s0
      gateway4: 192.168.122.1
      addresses:
        - ${IP}/${PREFIX}
      nameservers:
        addresses:
          - ${DATAPLANE_DNS_SERVER}
EOF

if [ ! -f ${EDPM_BOOTC_OUTPUT_DIR}/cidata.iso ]; then
    genisoimage -output ${EDPM_BOOTC_OUTPUT_DIR}/cidata.iso -V CIDATA -r -J ${EDPM_BOOTC_OUTPUT_DIR}/user-data ${EDPM_BOOTC_OUTPUT_DIR}/meta-data ${EDPM_BOOTC_OUTPUT_DIR}/network-config
fi

sudo podman run --rm -it --privileged \
    --security-opt label=type:unconfined_t \
    -v ${EDPM_BOOTC_OUTPUT_DIR}:/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v ${EDPM_BOOTC_OUTPUT_DIR}/config.toml:/config.toml:ro \
    ${EDPM_BOOTC_BUILDER_IMAGE} \
    --type qcow2 \
    ${EDPM_BOOTC_IMAGE}
sudo cp ${EDPM_BOOTC_OUTPUT_DIR}/qcow2/disk.qcow2 ${DISK_FILEPATH}

if ! virsh domuuid ${EDPM_COMPUTE_NAME}; then
    virsh define "${OUTPUT_DIR}/${EDPM_COMPUTE_NAME}.xml"
    virsh attach-disk ${EDPM_COMPUTE_NAME} $(realpath ${EDPM_BOOTC_OUTPUT_DIR}/cidata.iso) hdc --type cdrom --config --targetbus sata
else
    echo "${EDPM_COMPUTE_NAME} already defined in libvirt, not redefining."
fi
if [ "$(virsh domstate ${EDPM_COMPUTE_NAME})" != "running" ]; then
    virsh start ${EDPM_COMPUTE_NAME}
else
    echo "${EDPM_COMPUTE_NAME} already running."
fi
