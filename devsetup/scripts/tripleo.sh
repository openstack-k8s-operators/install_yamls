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

IP_ADRESS_SUFFIX=${IP_ADRESS_SUFFIX:-100}
IP=${IP:-"${EDPM_COMPUTE_NETWORK_IP%.*}.${IP_ADRESS_SUFFIX}"}
OS_NET_CONFIG_IFACE=${OS_NET_CONFIG_IFACE:-"nic1"}
CLOUD_DOMAIN=${CLOUD_DOMAIN:-localdomain}
GATEWAY=${GATEWAY:-"${EDPM_COMPUTE_NETWORK_IP}"}
OUTPUT_DIR=${OUTPUT_DIR:-"${SCRIPTPATH}/../../out/edpm/"}
SSH_KEY_FILE=${SSH_KEY_FILE:-"${OUTPUT_DIR}/ansibleee-ssh-key-id_rsa"}
SSH_OPT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY_FILE"
REPO_SETUP_CMDS=${REPO_SETUP_CMDS:-"${MY_TMP_DIR}/standalone_repos"}
CMDS_FILE=${CMDS_FILE:-"${MY_TMP_DIR}/standalone_cmds"}
SKIP_TRIPLEO_REPOS=${SKIP_TRIPLEO_REPOS:="false"}
TRIPLEO_NETWORKING=${TRIPLEO_NETWORKING:-true}
MANILA_ENABLED=${MANILA_ENABLED:-true}
OCTAVIA_ENABLED=${OCTAVIA_ENABLED:-false}
TELEMETRY_ENABLED=${TELEMETRY_ENABLED:-true}
TLSE_ENABLED=${TLSE_ENABLED:-false}

if [[ ! -f $SSH_KEY_FILE ]]; then
    echo "$SSH_KEY_FILE is missing"
    exit 1
fi

sudo dnf install -y python-jinja2
source ${SCRIPTPATH}/common.sh

# Clock synchronization is important for both Ceph and OpenStack services, so both ceph deploy and tripleo deploy commands will make use of chrony to ensure the clock is properly in sync.
# We'll use the NTP_SERVER environmental variable to define the NTP server to use, e.g.:
# export NTP_SERVER=pool.ntp.org

if [ $EDPM_COMPUTE_CELLS -ne 1 -a $EDPM_COMPUTE_CELLS -ne 3 ]; then
    echo "Only a main cell1 plus a 2 additional compute cells supported yet!"
    exit 1
fi

# TODO(bogdando): multi-cell with ceph HCI
if [ $EDPM_COMPUTE_CELLS -eq 3 ] && [[ "$EDPM_COMPUTE_CEPH_ENABLED" == "true" ]]; then
    echo "Ceph storage is not supported for multi-cell setup yet!"
    exit 1
fi

if [[ -e /run/systemd/resolve/resolv.conf ]]; then
    HOST_PRIMARY_RESOLV_CONF_ENTRY=$(cat /run/systemd/resolve/resolv.conf | grep ^nameserver | grep -v "${EDPM_COMPUTE_NETWORK_IP%.*}" | head -n1 | cut -d' ' -f2)
else
    HOST_PRIMARY_RESOLV_CONF_ENTRY=${HOST_PRIMARY_RESOLV_CONF_ENTRY:-$GATEWAY}
fi

set +x
cat <<EOF > $MY_TMP_DIR/.standalone_env_file
export RH_REGISTRY_USER="$REGISTRY_USER"
export RH_REGISTRY_PWD="$RH_REGISTRY_PWD"
EOF
chmod 0600 $MY_TMP_DIR/.standalone_env_file

cat <<EOF > $CMDS_FILE
. \$HOME/.standalone_env_file

set -ex
sudo dnf install -y podman python3-tripleoclient util-linux lvm2

sudo hostnamectl set-hostname undercloud.${CLOUD_DOMAIN}
sudo hostnamectl set-hostname undercloud.${CLOUD_DOMAIN} --transient

export HOST_PRIMARY_RESOLV_CONF_ENTRY=${HOST_PRIMARY_RESOLV_CONF_ENTRY}
export INTERFACE_MTU=${INTERFACE_MTU:-1500}
export NTP_SERVER=${NTP_SERVER:-"pool.ntp.org"}
export IP=${IP}
export GATEWAY=${GATEWAY}
export EDPM_COMPUTE_CEPH_ENABLED=${COMPUTE_CEPH_ENABLED:-false}
export EDPM_COMPUTE_CEPH_NOVA=${COMPUTE_CEPH_NOVA:-false}
export CEPH_ARGS="${CEPH_ARGS:--e \$HOME/deployed_ceph.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/cephadm/cephadm-rbd-only.yaml}"
[[ "\$EDPM_COMPUTE_CEPH_NOVA" == "false" ]] && export CEPH_ARGS="\${CEPH_ARGS} -e \$HOME/nova_noceph.yaml"
export EDPM_COMPUTE_CELLS=${COMPUTE_CELLS:-1}
export MANILA_ENABLED=${MANILA_ENABLED:-true}
export OCTAVIA_ENABLED=${OCTAVIA_ENABLED}
export TELEMETRY_ENABLED=${TELEMETRY_ENABLED:-true}
export TLSE_ENABLED=${TLSE_ENABLED:-false}
export CLOUD_DOMAIN=${CLOUD_DOMAIN:-localdomain}
export TRIPLEO_NETWORKING=${TRIPLEO_NETWORKING:-true}

set +x
if [ ! -f \$HOME/containers-prepare-parameters.yaml ]; then
    login_args=" "
    [ "\$RH_REGISTRY_USER" ] && [ -n "\$RH_REGISTRY_PWD" ] && login_args="--enable-registry-login"
    openstack tripleo container image prepare default \
        --output-env-file \$HOME/containers-prepare-parameters.yaml \${login_args}
    # Adoption requires Ceph 7 (Reef) as a requirement. Instead of performing a Ceph
    # upgrade from 6 (the default) to 7, let's try to deploy 7 in greenfield
    sed -i "s|rhceph-6-rhel9|rhceph-7-rhel9|" $HOME/containers-prepare-parameters.yaml
else
    echo "Using existing containers-prepare-parameters.yaml"
fi

if [ "\$RH_REGISTRY_USER" ] && [ -n "\$RH_REGISTRY_PWD" ]; then
    grep -q ContainerImageRegistryCredentials \$HOME/containers-prepare-parameters.yaml || \
    cat >> \$HOME/containers-prepare-parameters.yaml <<__EOF__
ContainerImageRegistryCredentials:
    registry.redhat.io:
        \${RH_REGISTRY_USER}: \$RH_REGISTRY_PWD
__EOF__
fi
set -x

# Use os-net-config to add VLAN interfaces which connect edpm-compute-0 to the isolated networks configured by install_yamls.
sudo mkdir -p /etc/os-net-config

cat << __EOF__ | sudo tee /etc/cloud/cloud.cfg.d/99-edpm-disable-network-config.cfg
network:
    config: disabled
__EOF__

cell=\$(( IP_ADRESS_SUFFIX - 100 ))
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

while [[ $(ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_OPT root@$IP echo ok) != "ok" ]]; do
    sleep 5
    true
done

# Render Jinja2 files
# FIXME: .99 undercloud IP cannot be changed https://review.rdoproject.org/cgit/rdo-jobs/tree/playbooks/data_plane_adoption/setup_tripleo_os_net_config.yaml#n6
# TODO(bogdnado): introduce CLOUD_USER var to remove all hardcoded 'zuul' values from these scripts
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
manage_default_route: ${TRIPLEO_NETWORKING}
attach_external_net: ${TRIPLEO_NETWORKING}
dns_server: ${PRIMARY_RESOLV_CONF_ENTRY}
user_home: /home/zuul
cloud_domain: ${CLOUD_DOMAIN}
EOF

jinja2_render ${SCRIPTPATH}/../tripleo/undercloud.conf.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/undercloud.conf
jinja2_render ${SCRIPTPATH}/../tripleo/net_config.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/net_config.yaml
jinja2_render ${SCRIPTPATH}/../tripleo/overcloud_services.yaml.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/overcloud_services.yaml
jinja2_render ${SCRIPTPATH}/../tripleo/config-download.yaml.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/config-download.yaml
jinja2_render ${SCRIPTPATH}/../tripleo/config-download-networker.yaml.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/config-download-networker.yaml
jinja2_render ${SCRIPTPATH}/../tripleo/network_data.yaml.j2 "${J2_VARS_FILE}" > ${MY_TMP_DIR}/network_data.yaml

# NOTE(bogdando): no computes supported in the cetnral overcloud stack in OSP.
# Reduced footprint for adoption dev envs: no HA controllers, an all-in-one host in the cell 2
ind=0
if [ $EDPM_COMPUTE_CELLS -gt 1 ]; then
    for cell in $(seq 0 $(( EDPM_COMPUTE_CELLS - 1))); do
        aio_count=0
        contr_count=0
        cell_contr_count=1
        comp_count=1
        if [ $cell -eq 0 ]; then
            contr_count=1
            cell_contr_count=0
            comp_count=0
        fi
        if [ $cell -ge 2 ]; then
            aio_count=1
            cell_contr_count=0
            comp_count=0
        fi

        J2_VARS_FILE=$(mktemp --suffix=".yaml" --tmpdir="${MY_TMP_DIR}")
        cat << EOF > ${J2_VARS_FILE}
---
cell: ${cell}
ind: ${ind}
max_cells: ${EDPM_COMPUTE_CELLS}
cloud_domain: ${CLOUD_DOMAIN}
aio_count: ${aio_count}
comp_count: ${comp_count}
cell_contr_count: ${cell_contr_count}
contr_count: ${contr_count}
gateway_ip: ${GATEWAY}
dns_server: ${PRIMARY_RESOLV_CONF_ENTRY}
tripleo_networking: ${TRIPLEO_NETWORKING}
EOF
        jinja2_render "${SCRIPTPATH}/../tripleo/network_data_cell.j2" "${J2_VARS_FILE}" > ${MY_TMP_DIR}/network_data${cell}.yaml
        jinja2_render "${SCRIPTPATH}/../tripleo/vips_data_cell.j2" "${J2_VARS_FILE}" > ${MY_TMP_DIR}/vips_data${cell}.yaml
        jinja2_render "${SCRIPTPATH}/../tripleo/overcloud_services_cell.j2" "${J2_VARS_FILE}" > ${MY_TMP_DIR}/overcloud_services_cell${cell}.yaml
        jinja2_render "${SCRIPTPATH}/../tripleo/config-download-multistack.j2" "${J2_VARS_FILE}" > ${MY_TMP_DIR}/config-download-cell${cell}.yaml
        ind=$(( ind + 1 ))
    done
fi

# Copying files
[ -f $REPO_SETUP_CMDS ] && scp $SSH_OPT $REPO_SETUP_CMDS root@$IP:/tmp/repo-setup.sh
scp $SSH_OPT $MY_TMP_DIR/.standalone_env_file zuul@$IP:.standalone_env_file
scp $SSH_OPT $CMDS_FILE zuul@$IP:/tmp/undercloud-deploy-cmds.sh
scp $SSH_OPT ${MY_TMP_DIR}/net_config.yaml root@$IP:/tmp/net_config.yaml
scp $SSH_OPT ${SCRIPTPATH}/../tripleo/tripleo_install.sh zuul@$IP:tripleo_install.sh
scp $SSH_OPT ${SCRIPTPATH}/../tripleo/hieradata_overrides_undercloud.yaml zuul@$IP:hieradata_overrides_undercloud.yaml
scp $SSH_OPT ${SCRIPTPATH}/../tripleo/undercloud-parameter-defaults.yaml zuul@$IP:undercloud-parameter-defaults.yaml
scp $SSH_OPT ${MY_TMP_DIR}/undercloud.conf zuul@$IP:undercloud.conf
scp $SSH_OPT ${SCRIPTPATH}/../tripleo/nova_noceph.yaml zuul@$IP:nova_noceph.yaml
if [ $EDPM_COMPUTE_CELLS -gt 1 ]; then
    for cell in $(seq 0 $(( EDPM_COMPUTE_CELLS - 1))); do
        scp $SSH_OPT ${MY_TMP_DIR}/vips_data${cell}.yaml zuul@$IP:vips_data${cell}.yaml
        scp $SSH_OPT ${MY_TMP_DIR}/network_data${cell}.yaml zuul@$IP:network_data${cell}.yaml
        scp $SSH_OPT ${MY_TMP_DIR}/overcloud_services_cell${cell}.yaml zuul@$IP:overcloud_services_cell${cell}.yaml
        scp $SSH_OPT ${MY_TMP_DIR}/config-download-cell${cell}.yaml zuul@$IP:config-download-cell${cell}.yaml
    done
else
    scp $SSH_OPT ${SCRIPTPATH}/../tripleo/vips_data.yaml zuul@$IP:vips_data.yaml
    scp $SSH_OPT ${MY_TMP_DIR}/network_data.yaml zuul@$IP:network_data.yaml
    scp $SSH_OPT ${MY_TMP_DIR}/overcloud_services.yaml zuul@$IP:overcloud_services.yaml
    scp $SSH_OPT  ${MY_TMP_DIR}/config-download.yaml zuul@$IP:config-download.yaml
    scp $SSH_OPT  ${MY_TMP_DIR}/config-download-networker.yaml zuul@$IP:config-download-networker.yaml
fi
scp $SSH_OPT ${SCRIPTPATH}/../tripleo/overcloud_roles.yaml zuul@$IP:overcloud_roles.yaml
scp $SSH_OPT ${SCRIPTPATH}/../tripleo/ansible_config.cfg zuul@$IP:ansible_config.cfg
if [[ "$EDPM_COMPUTE_CEPH_ENABLED" == "true" ]]; then
    scp $SSH_OPT ${SCRIPTPATH}/../tripleo/ceph.sh root@$IP:/tmp/ceph.sh
    scp $SSH_OPT ${SCRIPTPATH}/../tripleo/generate_ceph_inventory.py root@$IP:/tmp/generate_ceph_inventory.py
fi

if [[ -f $HOME/containers-prepare-parameters.yaml ]]; then
    echo "Using existing containers-prepare-parameters.yaml - contents:"
    # requires 'make download_tools'
    yq '.parameter_defaults.ContainerImageRegistryCredentials="{ ...snip... }"' $HOME/containers-prepare-parameters.yaml
    scp $SSH_OPT $HOME/containers-prepare-parameters.yaml zuul@$IP:containers-prepare-parameters.yaml
fi

# Running
if [[ -z ${SKIP_TRIPLEO_REPOS} || ${SKIP_TRIPLEO_REPOS} == "false" ]]; then
    [ -f $REPO_SETUP_CMDS ] && ssh $SSH_OPT root@$IP "bash /tmp/repo-setup.sh"
fi
ssh $SSH_OPT zuul@$IP "bash /tmp/undercloud-deploy-cmds.sh"
