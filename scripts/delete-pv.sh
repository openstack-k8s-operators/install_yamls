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
PV_NUM=${PV_NUM:-12}
# Default CRC private key location for OCP 4.18+
SSH_KEY=${SSH_KEY:-"${HOME}/.crc/machines/crc/id_ed25519"}

# OCP 4.17 and earlier
if [ ! -f "${SSH_KEY}" ]; then
    SSH_KEY="${HOME}/.crc/machines/crc/id_ecdsa"
fi

if [ -f "${SSH_KEY}" ]; then
    NODE_IPS=$(oc get nodes -o template --template '{{range .items}}{{range .status.addresses}}{{if eq .type "InternalIP"}}{{.address}}{{"\n"}}{{end }}{{end }}{{end }}')
    if [ -z "$NODE_IPS" ]; then
        echo "Unable to determine node IPs with 'oc' command."
        exit 1
    fi
    echo "Using SSH key located at ${SSH_KEY} for PV removal"
    for node in $NODE_IPS; do
        ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no core@"${node}" "for i in `seq -w -s ' ' $PV_NUM`; do echo \"deleting dir /mnt/openstack/pv\$i on $node\"; rm -rf /mnt/openstack/pv\$i; done"
    done
else
    NODE_NAMES=$(oc get node -o name -l node-role.kubernetes.io/worker)
    if [ -z "$NODE_NAMES" ]; then
        echo "Unable to determine node name with 'oc' command."
        exit 1
    fi
    echo "Using 'oc debug' for PV removal"
    for node in $NODE_NAMES; do
        oc debug $node -T -- chroot /host /usr/bin/bash -c "for i in `seq -w -s ' ' $PV_NUM`; do echo \"deleting dir /mnt/openstack/pv\$i on $node\"; rm -rf /mnt/openstack/pv\$i; done"
    done
fi
