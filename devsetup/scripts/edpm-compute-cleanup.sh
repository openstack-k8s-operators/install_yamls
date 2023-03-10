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
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
EDPM_COMPUTE_SUFFIX=${1:-"0"}
EDPM_COMPUTE_NAME=${EDPM_COMPUTE_NAME:-"edpm-compute-${EDPM_COMPUTE_SUFFIX}"}

XML="$(sudo virsh net-dumpxml default | grep $EDPM_COMPUTE_NAME \
       | sed -e 's/^[ \t]*//' | tr -d '\n')"
if [[ -n "$XML" ]]; then
    sudo virsh net-update default delete ip-dhcp-host --config --live --xml "$XML"
fi

RM_METADATA="--remove-all-metadata"
if [[ $(awk '{print $6}' /etc/redhat-release) =~ ^8.* ]]; then
    # virsh provided by RHEL8 Hypervisors does not support this option
    RM_METADATA=""
fi

sudo virsh destroy edpm-compute-${EDPM_COMPUTE_SUFFIX} || :
sudo virsh undefine --snapshots-metadata $RM_METADATA edpm-compute-${EDPM_COMPUTE_SUFFIX} || :
rm -f ${HOME}/.crc/machines/crc/edpm-compute-${EDPM_COMPUTE_SUFFIX}.qcow2
rm -f ../out/edpm/edpm-compute-*-id_rsa.pub
