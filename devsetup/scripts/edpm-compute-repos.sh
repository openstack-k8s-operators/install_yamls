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
IP_ADRESS_SUFFIX=${IP_ADRESS_SUFFIX:-"$((100+${EDPM_COMPUTE_SUFFIX}))"}
IP="192.168.122.${IP_ADRESS_SUFFIX}"
OUTPUT_DIR=${OUTPUT_DIR:-"${SCRIPTPATH}/../../out/edpm/"}
SSH_KEY_FILE=${SSH_KEY_FILE:-"${OUTPUT_DIR}/ansibleee-ssh-key-id_rsa"}
SSH_OPT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY_FILE"
CMDS_FILE=${CMDS_FILE:-"/tmp/edpm_compute_repos"}
REPO_SETUP_CMD=${REPO_SETUP_CMD:-"current-podified-dev"}
CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD:-"rm -Rf"}

if [[ ! -f $SSH_KEY_FILE ]]; then
    echo "$SSH_KEY_FILE is missing"
    exit 1
fi

if [[ ! -f $CMDS_FILE ]]; then
cat <<EOF > $CMDS_FILE
#!/bin/bash
set -ex
# Install latest version of repo-setup without installing pip or git
pushd /tmp
curl -sL https://github.com/openstack-k8s-operators/repo-setup/archive/refs/heads/main.tar.gz | tar -xz
pushd repo-setup-main
python3 -m venv ./venv
PBR_VERSION=0.0.0 ./venv/bin/pip install ./
./venv/bin/repo-setup ${REPO_SETUP_CMD}
popd
popd
EOF
fi

scp $SSH_OPT $CMDS_FILE root@$IP:/tmp/repo-setup.sh
ssh $SSH_OPT root@$IP "bash /tmp/repo-setup.sh; rm -f /tmp/repo-setup.sh"
${CLEANUP_DIR_CMD} $CMDS_FILE
