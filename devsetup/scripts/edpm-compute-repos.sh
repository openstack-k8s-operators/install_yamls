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
IP=$( sudo virsh -q domifaddr $EDPM_COMPUTE_NAME | awk 'NF>1{print $NF}' | cut -d/ -f1 )
SSH_KEY="$SCRIPTPATH/../../out/edpm/ansibleee-ssh-key-id_rsa"
SSH_OPT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY"
CMDS_FILE="/tmp/edpm_compute_repos"

if [[ ! -f $SSH_KEY ]]; then
    echo "$SSH_KEY is missing"
    exit 1
fi

cat <<EOF > $CMDS_FILE
rpm -q git || sudo yum -y install git
sudo yum -y install python-setuptools python-requests python3-pip
git clone https://git.openstack.org/openstack/tripleo-repos
pushd tripleo-repos
sudo python3 setup.py install
popd
sudo /usr/local/bin/tripleo-repos current-tripleo-dev
EOF

scp $SSH_OPT $CMDS_FILE root@$IP:$CMDS_FILE
ssh $SSH_OPT root@$IP "bash $CMDS_FILE; rm -f $CMDS_FILE"
rm -f $CMDS_FILE
