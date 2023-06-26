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
CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD:-"rm -Rf"}

virsh destroy ${EDPM_COMPUTE_NAME} || :
virsh undefine --snapshots-metadata --remove-all-storage ${EDPM_COMPUTE_NAME} || :
${CLEANUP_DIR_CMD} "${CRC_POOL}/${EDPM_COMPUTE_NAME}.qcow2"
