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
. ${SCRIPTPATH}/common.sh --source-only

export VIRSH_DEFAULT_CONNECT_URI=qemu:///system
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
EDPM_SERVER_ROLE=${EDPM_SERVER_ROLE:-"compute"}
EDPM_COMPUTE_SUFFIX=${1:-"0"}
EDPM_COMPUTE_NAME=${EDPM_COMPUTE_NAME:-"edpm-${EDPM_SERVER_ROLE}-${EDPM_COMPUTE_SUFFIX}"}
CRC_POOL=${CRC_POOL:-"$HOME/.crc/machines/crc"}
OUTPUT_DIR=${OUTPUT_DIR:-"../out/edpm/"}
REPO_SETUP_CMDS=${REPO_SETUP_CMDS:-"/tmp/standalone_repos"}
CMDS_FILE=${CMDS_FILE:-"/tmp/standalone_cmds"}
CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD:-"rm -Rf"}
STANDALONE=${STANDALONE:-false}

virsh destroy ${EDPM_COMPUTE_NAME} || :
virsh undefine --snapshots-metadata --remove-all-storage ${EDPM_COMPUTE_NAME} || :
${CLEANUP_DIR_CMD} "${CRC_POOL}/${EDPM_COMPUTE_NAME}.qcow2"

chassis_uuid=$(run_ovn_ctl_command SB --format=csv --data=bare --columns=name,hostname list chassis | awk -F "," "/,${EDPM_COMPUTE_NAME}/{ print \$1 }")

if [ "x" != "x$chassis_uuid" ]; then
    run_ovn_ctl_command SB chassis-del $chassis_uuid
fi

# We don't know the domain of the FQDN so we need to search for the name
compute_service_uuid=$(run_openstack_command compute service list -c ID -c Host --service nova-compute -f value | awk "/${EDPM_COMPUTE_NAME}/{ print \$1 }")
if [ "x" != "x$compute_service_uuid" ]; then
    run_openstack_command compute service delete $compute_service_uuid
fi

if [ ${STANDALONE} = "true" ]; then
    ${CLEANUP_DIR_CMD} $CMDS_FILE
    ${CLEANUP_DIR_CMD} $REPO_SETUP_CMDS
fi
