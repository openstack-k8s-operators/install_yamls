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
CMDS_FILE=${CMDS_FILE:-"/tmp/standalone_repos"}
CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD:-"rm -Rf"}

if [[ ! -f $SSH_KEY_FILE ]]; then
    echo "$SSH_KEY_FILE is missing"
    exit 1
fi

# Clock synchronization is important for both Ceph and OpenStack services, so both ceph deploy and tripleo deploy commands will make use of chrony to ensure the clock is properly in sync.
# We'll use the NTP_SERVER environmental variable to define the NTP server to use.
# If we are running alls these commands in a system inside the Red Hat network we should use the clock.corp.redhat.com server:
# export NTP_SERVER=clock.corp.redhat.com
# And when running it from our own systems outside of the Red Hat network we can use any available server:
# export NTP_SERVER=pool.ntp.org

if [[ ! -f $CMDS_FILE ]]; then
cat <<EOF > $CMDS_FILE
set -ex
sudo dnf remove -y epel-release
sudo dnf update -y
sudo dnf install -y vim git curl util-linux lvm2 tmux wget
URL=https://trunk.rdoproject.org/centos9/component/tripleo/current/
RPM_NAME=\$(curl \$URL | grep python3-tripleo-repos | sed -e 's/<[^>]*>//g' | awk 'BEGIN { FS = ".rpm" } ; { print \$1 }')
RPM=\$RPM_NAME.rpm
sudo dnf install -y \$URL\$RPM
sudo -E tripleo-repos -b wallaby current-tripleo-dev ceph --stream
sudo dnf repolist
sudo dnf update -y
sudo dnf install -y podman python3-tripleoclient util-linux lvm2 cephadm

sudo hostnamectl set-hostname standalone.localdomain
sudo hostnamectl set-hostname standalone.localdomain --transient

export INTERFACE_MTU=${INTERFACE_MTU:-1500}
export NTP_SERVER=${NTP_SERVER:-"clock.corp.redhat.com"}
export EDPM_COMPUTE_CEPH_ENABLED=${EDPM_COMPUTE_CEPH_ENABLED:-true}
export CEPH_ARGS=${CEPH_ARGS:-\"-e \$HOME/deployed_ceph.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/cephadm/cephadm-rbd-only.yaml\"}

/tmp/network.sh
[[ "\$EDPM_COMPUTE_CEPH_ENABLED" == "true" ]] && /tmp/ceph.sh
/tmp/openstack.sh
EOF
fi

while [[ $(ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_OPT root@$IP echo ok) != "ok" ]]; do
    true
done

# Copying files
scp $SSH_OPT $CMDS_FILE root@$IP:/tmp/repo-setup.sh
scp $SSH_OPT standalone/standalone.j2 root@$IP:/tmp/standalone.j2
scp $SSH_OPT standalone/network_data.yaml root@$IP:/tmp/network_data.yaml
scp $SSH_OPT standalone/deployed_network.yaml root@$IP:/tmp/deployed_network.yaml
scp $SSH_OPT standalone/network.sh root@$IP:/tmp/network.sh
scp $SSH_OPT standalone/ceph.sh root@$IP:/tmp/ceph.sh
scp $SSH_OPT standalone/openstack.sh root@$IP:/tmp/openstack.sh

# Running
ssh $SSH_OPT root@$IP "bash /tmp/repo-setup.sh"
# separate the two commands so we can properly detect whether there is
# a failure while deploying standalone
ssh $SSH_OPT root@$IP "rm -f /tmp/repo-setup.sh"
${CLEANUP_DIR_CMD} $CMDS_FILE
