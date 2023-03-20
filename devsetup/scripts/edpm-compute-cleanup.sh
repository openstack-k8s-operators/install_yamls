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
export VIRSH_DEFAULT_CONNECT_URI=qemu:///system
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
EDPM_COMPUTE_SUFFIX=${1:-"0"}
EDPM_COMPUTE_NAME=${EDPM_COMPUTE_NAME:-"edpm-compute-${EDPM_COMPUTE_SUFFIX}"}
CRC_POOL=${CRC_POOL:-"$HOME/.crc/machines/crc"}
OUTPUT_BASEDIR=${OUTPUT_BASEDIR:-"../out/edpm/"}

XML="$(virsh net-dumpxml default | grep $EDPM_COMPUTE_NAME \
    | sed -e 's/^[ \t]*//' | tr -d '\n')"
if [[ -n "$XML" ]]; then
    virsh net-update default delete ip-dhcp-host --config --live --xml "$XML"
fi

virsh destroy edpm-compute-${EDPM_COMPUTE_SUFFIX} || :
virsh undefine --snapshots-metadata --remove-all-storage edpm-compute-${EDPM_COMPUTE_SUFFIX} || :
rm -f "${CRC_POOL}/edpm-compute-${EDPM_COMPUTE_SUFFIX}.qcow2"
rm -f ${OUTPUT_BASEDIR}/edpm-compute-*-id_rsa.pub
