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

MY_TMP_DIR="$(mktemp -d)"
trap 'rv=$?; rm -rf -- "$MY_TMP_DIR"; exit $rv' EXIT

export VIRSH_DEFAULT_CONNECT_URI=qemu:///system
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
EDPM_COMPUTE_SUFFIX=${1:-"0"}
COMPUTE_DRIVER=${2:-"libvirt"}
EDPM_COMPUTE_ADDITIONAL_NETWORKS=${3:-'[]'}
EDPM_COMPUTE_ADDITIONAL_HOST_ROUTES=${4:-'[]'}
EDPM_COMPUTE_NAME=${EDPM_COMPUTE_NAME:-"edpm-compute-${EDPM_COMPUTE_SUFFIX}"}
EDPM_COMPUTE_NETWORK=${EDPM_COMPUTE_NETWORK:-default}
STANDALONE_VM=${STANDALONE_VM:-"true"}
if [[ ${STANDALONE_VM} == "true" ]]; then
    EDPM_COMPUTE_NETWORK_IP=$(virsh net-dumpxml ${EDPM_COMPUTE_NETWORK} | xmllint --xpath 'string(/network/ip/@address)' -)
fi
IP_ADRESS_SUFFIX=$((100+${EDPM_COMPUTE_SUFFIX}))
IP=${IP:-"${EDPM_COMPUTE_NETWORK_IP%.*}.${IP_ADRESS_SUFFIX}"}
OS_NET_CONFIG_IFACE=${OS_NET_CONFIG_IFACE:-"nic1"}
GATEWAY=${GATEWAY:-"${EDPM_COMPUTE_NETWORK_IP}"}
OUTPUT_DIR=${OUTPUT_DIR:-"${SCRIPTPATH}/../../out/edpm/"}
SSH_KEY_FILE=${SSH_KEY_FILE:-"${OUTPUT_DIR}/ansibleee-ssh-key-id_rsa"}
SSH_OPT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY_FILE"
REPO_SETUP_CMDS=${REPO_SETUP_CMDS:-"${MY_TMP_DIR}/standalone_repos"}
CMDS_FILE=${CMDS_FILE:-"${MY_TMP_DIR}/standalone_cmds"}
SKIP_TRIPLEO_REPOS=${SKIP_TRIPLEO_REPOS:="false"}
CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD:-"rm -Rf"}
EDPM_COMPUTE_VCPUS=${COMPUTE_VCPUS:-8}
EDPM_COMPUTE_RAM=${COMPUTE_RAM:-20}
EDPM_COMPUTE_DISK_SIZE=${COMPUTE_DISK_SIZE:-70}
EDPM_CONFIGURE_HUGEPAGES=${CONFIGURE_HUGEPAGES:-false}
EDPM_COMPUTE_CEPH_ENABLED=${COMPUTE_CEPH_ENABLED:-true}
EDPM_COMPUTE_CEPH_NOVA=${COMPUTE_CEPH_NOVA:-true}
EDPM_COMPUTE_SRIOV_ENABLED=${COMPUTE_SRIOV_ENABLED:-true}
EDPM_COMPUTE_DHCP_AGENT_ENABLED=${COMPUTE_DHCP_AGENT_ENABLED:-true}
BARBICAN_ENABLED=${BARBICAN_ENABLED:-true}
MANILA_ENABLED=${MANILA_ENABLED:-true}
SWIFT_REPLICATED=${SWIFT_REPLICATED:-false}
TLSE_ENABLED=${TLSE_ENABLED:-false}
CLOUD_DOMAIN=${CLOUD_DOMAIN:-localdomain}
OCTAVIA_ENABLED=${OCTAVIA_ENABLED:-false}
TELEMETRY_ENABLED=${TELEMETRY_ENABLED:-true}


if [[ ! -f $SSH_KEY_FILE ]]; then
    echo "$SSH_KEY_FILE is missing"
    exit 1
fi

source ${SCRIPTPATH}/common.sh

# Clock synchronization is important for both Ceph and OpenStack services, so both ceph deploy and tripleo deploy commands will make use of chrony to ensure the clock is properly in sync.
# We'll use the NTP_SERVER environmental variable to define the NTP server to use, e.g.:
# export NTP_SERVER=pool.ntp.org

if [[ ! -f $REPO_SETUP_CMDS ]]; then
    cat <<EOF > $REPO_SETUP_CMDS
set -ex
sudo dnf remove -y epel-release
sudo dnf update -y
sudo dnf install -y vim git curl util-linux lvm2 tmux wget
URL=https://trunk.rdoproject.org/centos9-wallaby/component/tripleo/current-tripleo/
RPM_NAME=\$(curl \$URL | grep python3-tripleo-repos | sed -e 's/<[^>]*>//g' | awk 'BEGIN { FS = ".rpm" } ; { print \$1 }')
RPM=\$RPM_NAME.rpm
sudo dnf install -y \$URL\$RPM
sudo -E tripleo-repos -b wallaby current-tripleo-dev ceph --stream
sudo dnf repolist
sudo dnf update -y
EOF
fi

if [[ -e /run/systemd/resolve/resolv.conf ]]; then
    HOST_PRIMARY_RESOLV_CONF_ENTRY=$(cat /run/systemd/resolve/resolv.conf | grep ^nameserver | grep -v "${EDPM_COMPUTE_NETWORK_IP%.*}" | head -n1 | cut -d' ' -f2)
else
    HOST_PRIMARY_RESOLV_CONF_ENTRY=${HOST_PRIMARY_RESOLV_CONF_ENTRY:-$GATEWAY}
fi

if [[ ! -f $CMDS_FILE ]]; then
    cat <<EOF > $CMDS_FILE
set -ex
sudo dnf install -y podman python3-tripleoclient util-linux lvm2 cephadm

sudo hostnamectl set-hostname standalone.${CLOUD_DOMAIN}
sudo hostnamectl set-hostname standalone.${CLOUD_DOMAIN} --transient

cat >\$HOME/nova_noceph.yaml <<__EOF__
parameter_defaults:
    NovaEnableRbdBackend: false
__EOF__

cat >\$HOME/sriov_template.yaml <<__EOF__
parameter_defaults:
    NovaPCIPassthrough:
      - devname: "dummy-dev"
        physical_network: "dummy_sriov_net"
    NeutronPhysicalDevMappings: "dummy_sriov_net:dummy-dev"
__EOF__

cat >\$HOME/dhcp_agent_template.yaml <<__EOF__
parameter_defaults:
  NeutronEnableForceMetadata: true
  DhcpAgentNotification: true

resource_registry:
  OS::TripleO::Services::NeutronDhcpAgent: deployment/neutron/neutron-dhcp-container-puppet.yaml
__EOF__

export HOST_PRIMARY_RESOLV_CONF_ENTRY=${HOST_PRIMARY_RESOLV_CONF_ENTRY}
export INTERFACE_MTU=${INTERFACE_MTU:-1500}
export NTP_SERVER=${NTP_SERVER:-"pool.ntp.org"}
export EDPM_CONFIGURE_HUGEPAGES=${EDPM_CONFIGURE_HUGEPAGES:-false}
export EDPM_COMPUTE_CEPH_ENABLED=${EDPM_COMPUTE_CEPH_ENABLED:-true}
export EDPM_COMPUTE_CEPH_NOVA=${EDPM_COMPUTE_CEPH_NOVA:-true}
export CEPH_ARGS="${CEPH_ARGS:--e \$HOME/deployed_ceph.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/cephadm/cephadm-rbd-only.yaml}"
[[ "\$EDPM_COMPUTE_CEPH_NOVA" == "false" ]] && export CEPH_ARGS="\${CEPH_ARGS} -e \$HOME/nova_noceph.yaml"
export COMPUTE_DRIVER=${COMPUTE_DRIVER:-"libvirt"}
export IP=${IP}
export GATEWAY=${GATEWAY}
export STANDALONE_VM=${STANDALONE_VM}
export BARBICAN_ENABLED=${BARBICAN_ENABLED}
export MANILA_ENABLED=${MANILA_ENABLED}
export SWIFT_REPLICATED=${SWIFT_REPLICATED}
export TLSE_ENABLED=${TLSE_ENABLED}
export CLOUD_DOMAIN=${CLOUD_DOMAIN}
export OCTAVIA_ENABLED=${OCTAVIA_ENABLED}
export TELEMETRY_ENABLED=${TELEMETRY_ENABLED}

if [[ -f \$HOME/containers-prepare-parameters.yaml ]]; then
    echo "Using existing containers-prepare-parameters.yaml - contents:"
    cat \$HOME/containers-prepare-parameters.yaml
else
    openstack tripleo container image prepare default \
        --output-env-file \$HOME/containers-prepare-parameters.yaml
    # Use wallaby el9 container images
    sed -i 's|quay.io/tripleowallaby$|quay.io/tripleowallabycentos9|' \$HOME/containers-prepare-parameters.yaml
    # Adoption requires Ceph 7 (Reef) as a requirement. Instead of performing a Ceph
    # upgrade from 6 (the default) to 7, let's try to deploy 7 in greenfield
    sed -i "s|rhceph-6-rhel9|rhceph-7-rhel9|" \$HOME/containers-prepare-parameters.yaml
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

#---
## Copying files
#---
# Use /tmp/net_config.yaml as the network config template for Standalone
# so that tripleo deploy don't change the config applied above.
sudo cp /tmp/net_config.yaml \$HOME/standalone_net_config.j2
sudo cp /tmp/network_data.yaml \$HOME/network_data.yaml
sudo cp /tmp/deployed_network.yaml \$HOME/deployed_network.yaml
sudo cp /tmp/Standalone.yaml \$HOME/Standalone.yaml
#----

[[ "\$EDPM_COMPUTE_CEPH_ENABLED" == "true" ]] && /tmp/ceph.sh
/tmp/openstack.sh
[[ "\$COMPUTE_DRIVER" == "ironic" ]] && /tmp/ironic_post.sh

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
if [ ${COMPUTE_DRIVER} == 'ironic' ]; then
    PRIMARY_RESOLV_CONF_ENTRY="192.168.130.11"  # Use crc for dns to enable resolving apps-crc.testing
    # Add a hosts entry for the network address to speed up iptables
    ssh $SSH_OPT root@$IP "echo ${IP%.*}.0 .${CLOUD_DOMAIN} >> /etc/hosts"
else
    PRIMARY_RESOLV_CONF_ENTRY=${HOST_PRIMARY_RESOLV_CONF_ENTRY}
fi
J2_VARS_FILE=$(mktemp --suffix=".yaml" --tmpdir="${MY_TMP_DIR}")
cat << EOF > ${J2_VARS_FILE}
---
additional_networks: ${EDPM_COMPUTE_ADDITIONAL_NETWORKS}
additional_host_routes: ${EDPM_COMPUTE_ADDITIONAL_HOST_ROUTES}
ctlplane_cidr: 24
ctlplane_ip: ${IP}
os_net_config_iface: ${OS_NET_CONFIG_IFACE}
standalone_vm: ${STANDALONE_VM}
ctlplane_subnet: ${IP%.*}.0/24
ctlplane_vip: ${IP%.*}.99
ip_address_suffix: ${IP_ADRESS_SUFFIX}
interface_mtu: ${INTERFACE_MTU:-1500}
gateway_ip: ${GATEWAY}
dns_server: ${PRIMARY_RESOLV_CONF_ENTRY}
compute_driver: ${COMPUTE_DRIVER}
sriov_agent: ${EDPM_COMPUTE_SRIOV_ENABLED}
dhcp_agent: ${EDPM_COMPUTE_DHCP_AGENT_ENABLED}
EOF

jinja2_render standalone/network_data.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/network_data.yaml
jinja2_render standalone/deployed_network.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/deployed_network.yaml
jinja2_render standalone/net_config.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/net_config.yaml
jinja2_render standalone/role.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/Standalone.yaml

# Copying files
scp $SSH_OPT $REPO_SETUP_CMDS root@$IP:/tmp/repo-setup.sh
scp $SSH_OPT $CMDS_FILE root@$IP:/tmp/standalone-deploy.sh
scp $SSH_OPT ${MY_TMP_DIR}/net_config.yaml root@$IP:/tmp/net_config.yaml
scp $SSH_OPT ${MY_TMP_DIR}/network_data.yaml root@$IP:/tmp/network_data.yaml
scp $SSH_OPT ${MY_TMP_DIR}/deployed_network.yaml root@$IP:/tmp/deployed_network.yaml
scp $SSH_OPT ${MY_TMP_DIR}/Standalone.yaml root@$IP:/tmp/Standalone.yaml
scp $SSH_OPT ${SCRIPTPATH}/../standalone/hugepages.yaml root@$IP:hugepages.yaml
[[ "$EDPM_COMPUTE_CEPH_ENABLED" == "true" ]] && scp $SSH_OPT standalone/ceph.sh root@$IP:/tmp/ceph.sh
scp $SSH_OPT standalone/openstack.sh root@$IP:/tmp/openstack.sh
scp $SSH_OPT standalone/post_config/ironic.sh root@$IP:/tmp/ironic_post.sh
[ -f $HOME/.ssh/id_ecdsa.pub ] || \
    ssh-keygen -t ecdsa -f $HOME/.ssh/id_ecdsa -q -N ""
scp $SSH_OPT $HOME/.ssh/id_ecdsa.pub root@$IP:/root/.ssh/id_ecdsa.pub
if [[ -f $HOME/containers-prepare-parameters.yaml ]]; then
    scp $SSH_OPT $HOME/containers-prepare-parameters.yaml root@$IP:/root/containers-prepare-parameters.yaml
fi

# Running
if [[ -z ${SKIP_TRIPLEO_REPOS} || ${SKIP_TRIPLEO_REPOS} == "false" ]]; then
    ssh $SSH_OPT root@$IP "bash /tmp/repo-setup.sh"
    # separate the two commands so we can properly detect whether there is
    # a failure while deploying standalone
    ssh $SSH_OPT root@$IP "rm -f /tmp/repo-setup.sh"
fi
if [[ -n ${STANDALONE_EXTRA_CMD} ]]; then
    ssh $SSH_OPT root@$IP "${STANDALONE_EXTRA_CMD}"
fi
ssh $SSH_OPT root@$IP "bash /tmp/standalone-deploy.sh"
deploy_result="$?"
ssh $SSH_OPT root@$IP "rm -f /tmp/standalone-deploy.sh"
exit $deploy_result
