#!/bin/bash
#
# Copyright 2024 Red Hat Inc.
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

MY_TMP_DIR="$(mktemp -d)"
trap 'rv=$?; rm -rf -- "$MY_TMP_DIR"; exit $rv' EXIT

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

IP=${IP:-"${EDPM_COMPUTE_NETWORK_IP%.*}.${IP_ADRESS_SUFFIX}"}
OS_NET_CONFIG_IFACE=${OS_NET_CONFIG_IFACE:-"nic1"}
GATEWAY=${GATEWAY:-"${EDPM_COMPUTE_NETWORK_IP}"}
OUTPUT_DIR=${OUTPUT_DIR:-"${SCRIPTPATH}/../../out/edpm/"}
SSH_KEY_FILE=${SSH_KEY_FILE:-"${OUTPUT_DIR}/ansibleee-ssh-key-id_rsa"}
SSH_OPT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY_FILE"
REPO_SETUP_CMDS=${REPO_SETUP_CMDS:-"${MY_TMP_DIR}/standalone_repos"}
CMDS_FILE=${CMDS_FILE:-"${MY_TMP_DIR}/standalone_cmds"}
SKIP_TRIPLEO_REPOS=${SKIP_TRIPLEO_REPOS:="false"}
MANILA_ENABLED=${MANILA_ENABLED:-true}
OCTAVIA_ENABLED=${OCTAVIA_ENABLED:-true}

if [[ ! -f $SSH_KEY_FILE ]]; then
    echo "$SSH_KEY_FILE is missing"
    exit 1
fi

source ${SCRIPTPATH}/common.sh

if [[ -e /run/systemd/resolve/resolv.conf ]]; then
    HOST_PRIMARY_RESOLV_CONF_ENTRY=$(cat /run/systemd/resolve/resolv.conf | grep ^nameserver | grep -v "${EDPM_COMPUTE_NETWORK_IP%.*}" | head -n1 | cut -d' ' -f2)
else
    HOST_PRIMARY_RESOLV_CONF_ENTRY=${HOST_PRIMARY_RESOLV_CONF_ENTRY:-$GATEWAY}
fi

if [[ ! -f $CMDS_FILE ]]; then
    cat <<EOF > $CMDS_FILE
set -ex
sudo dnf install -y podman python3-tripleoclient util-linux lvm2

sudo hostnamectl set-hostname undercloud.localdomain
sudo hostnamectl set-hostname undercloud.localdomain --transient

export HOST_PRIMARY_RESOLV_CONF_ENTRY=${HOST_PRIMARY_RESOLV_CONF_ENTRY}
export INTERFACE_MTU=${INTERFACE_MTU:-1500}
export NTP_SERVER=${NTP_SERVER:-"clock.corp.redhat.com"}
export IP=${IP}
export GATEWAY=${GATEWAY}
export EDPM_COMPUTE_CEPH_ENABLED=${EDPM_COMPUTE_CEPH_ENABLED:-false}
export CEPH_ARGS="${CEPH_ARGS:--e \$HOME/deployed_ceph.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/cephadm/cephadm.yaml}"
export MANILA_ENABLED=${MANILA_ENABLED:-true}
export OCTAVIA_ENABLED=${OCTAVIA_ENABLED:-true}

if [[ -f \$HOME/containers-prepare-parameters.yaml ]]; then
    echo "Using existing containers-prepare-parameters.yaml - contents:"
    cat \$HOME/containers-prepare-parameters.yaml
else
    openstack tripleo container image prepare default \
        --output-env-file \$HOME/containers-prepare-parameters.yaml
    # Use wallaby el9 container images
    sed -i 's|quay.io/tripleowallaby$|quay.io/tripleowallabycentos9|' \$HOME/containers-prepare-parameters.yaml
fi

# Use os-net-config to add VLAN interfaces which connect edpm-compute-0 to the isolated networks configured by install_yamls.
sudo mkdir -p /etc/os-net-config

cat << __EOF__ | sudo tee /etc/cloud/cloud.cfg.d/99-edpm-disable-network-config.cfg
network:
    config: disabled
__EOF__

sudo systemctl enable network
sudo cp /tmp/net_config.yaml /etc/os-net-config/config.yaml
sudo os-net-config -c /etc/os-net-config/config.yaml

pushd \$HOME
\$HOME/tripleo_install.sh
popd

# explicitely return exit code 0 when we reach the end of the script
# if the script ends with a test chained to a command with an '&&' and the test
# is not true, the script will return 0 and cause an error in CI
exit 0
EOF
fi

while [[ $(ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_OPT root@$IP echo ok) != "ok" ]]; do
    sleep 5
    true
done

# Render Jinja2 files
PRIMARY_RESOLV_CONF_ENTRY=${HOST_PRIMARY_RESOLV_CONF_ENTRY}
J2_VARS_FILE=$(mktemp --suffix=".yaml" --tmpdir="${MY_TMP_DIR}")
cat << EOF > ${J2_VARS_FILE}
---
ctlplane_cidr: 24
ctlplane_ip: ${IP}
os_net_config_iface: ${OS_NET_CONFIG_IFACE}
ctlplane_vip: ${IP%.*}.99
ip_address_suffix: ${IP_ADRESS_SUFFIX}
interface_mtu: ${INTERFACE_MTU:-1500}
ntp_server: ${NTP_SERVER}
gateway_ip: ${GATEWAY}
dns_server: ${PRIMARY_RESOLV_CONF_ENTRY}
user_home: ${HOME}
EOF

jinja2_render tripleo/net_config.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/net_config.yaml
jinja2_render tripleo/undercloud.conf.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/undercloud.conf

# Copying files
scp $SSH_OPT $REPO_SETUP_CMDS root@$IP:/tmp/repo-setup.sh
scp $SSH_OPT $CMDS_FILE zuul@$IP:/tmp/undercloud-deploy-cmds.sh
scp $SSH_OPT ${MY_TMP_DIR}/net_config.yaml root@$IP:/tmp/net_config.yaml
scp $SSH_OPT tripleo/tripleo_install.sh zuul@$IP:$HOME/tripleo_install.sh
scp $SSH_OPT tripleo/hieradata_overrides_undercloud.yaml zuul@$IP:$HOME/hieradata_overrides_undercloud.yaml
scp $SSH_OPT tripleo/undercloud-parameter-defaults.yaml zuul@$IP:$HOME/undercloud-parameter-defaults.yaml
scp $SSH_OPT ${MY_TMP_DIR}/undercloud.conf zuul@$IP:$HOME/undercloud.conf
scp $SSH_OPT tripleo/network_data.yaml zuul@$IP:$HOME/network_data.yaml
scp $SSH_OPT tripleo/vips_data.yaml zuul@$IP:$HOME/vips_data.yaml
scp $SSH_OPT tripleo/config-download.yaml zuul@$IP:$HOME/config-download.yaml
scp $SSH_OPT tripleo/overcloud_roles.yaml zuul@$IP:$HOME/overcloud_roles.yaml
scp $SSH_OPT tripleo/overcloud_services.yaml zuul@$IP:$HOME/overcloud_services.yaml
scp $SSH_OPT tripleo/ansible_config.cfg zuul@$IP:$HOME/ansible_config.cfg
if [[ "$EDPM_COMPUTE_CEPH_ENABLED" == "true" ]]; then
    scp $SSH_OPT tripleo/ceph.sh root@$IP:/tmp/ceph.sh
    scp $SSH_OPT tripleo/generate_ceph_inventory.py root@$IP:/tmp/generate_ceph_inventory.py
fi

if [[ -f $HOME/containers-prepare-parameters.yaml ]]; then
    scp $SSH_OPT $HOME/containers-prepare-parameters.yaml zuul@$IP:$HOME/containers-prepare-parameters.yaml
fi

# Running
if [[ -z ${SKIP_TRIPLEO_REPOS} || ${SKIP_TRIPLEO_REPOS} == "false" ]]; then
    ssh $SSH_OPT root@$IP "bash /tmp/repo-setup.sh"
fi
ssh $SSH_OPT zuul@$IP "bash /tmp/undercloud-deploy-cmds.sh"
