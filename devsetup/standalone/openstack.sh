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

EDPM_COMPUTE_CEPH_ENABLED=${EDPM_COMPUTE_CEPH_ENABLED:-true}
EDPM_COMPUTE_SRIOV_ENABLED=${EDPM_COMPUTE_SRIOV_ENABLED:-true}
EDPM_COMPUTE_DHCP_AGENT_ENABLED=${EDPM_COMPUTE_DHCP_AGENT_ENABLED:-true}
COMPUTE_DRIVER=${COMPUTE_DRIVER:-"libvirt"}
INTERFACE_MTU=${INTERFACE_MTU:-1500}
BARBICAN_ENABLED=${BARBICAN_ENABLED:-true}
MANILA_ENABLED=${MANILA_ENABLED:-true}
SWIFT_REPLICATED=${SWIFT_REPLICATED:-false}
TLSE_ENABLED=${TLSE_ENABLED:-false}
CLOUD_DOMAIN=${CLOUD_DOMAIN:-localdomain}
TELEMETRY_ENABLED=${TELEMETRY_ENABLED:-true}
OCTAVIA_ENABLED=${OCTAVIA_ENABLED:-false}
IPA_IMAGE=${IPA_IMAGE:-"quay.io/freeipa/freeipa-server:fedora-41"}

# Use the files created in the previous steps including the network_data.yaml file and thw deployed_network.yaml file.
# The deployed_network.yaml file hard codes the IPs and VIPs configured from the network.sh

export NEUTRON_INTERFACE=eth0
export CTLPLANE_IP=${IP:-192.168.122.100}
export CTLPLANE_VIP=${CTLPLANE_IP%.*}.99
export CIDR=24
export GATEWAY=${GATEWAY:-192.168.122.1}
export BRIDGE="br-ctlplane"
if [ "$COMPUTE_DRIVER" = "ironic" ]; then
    BRIDGE_MAPPINGS=${BRIDGE_MAPPINGS:-"datacentre:${BRIDGE},baremetal:br-baremetal"}
    NEUTRON_FLAT_NETWORKS=${NEUTRON_FLAT_NETWORKS:-"datacentre,baremetal"}
else
    BRIDGE_MAPPINGS=${BRIDGE_MAPPINGS:-"datacentre:${BRIDGE}"}
    NEUTRON_FLAT_NETWORKS=${NEUTRON_FLAT_NETWORKS:-"datacentre"}
fi

# Create standalone_parameters.yaml file and deploy standalone OpenStack using the following commands.
cat <<EOF > standalone_parameters.yaml
parameter_defaults:
  BarbicanSimpleCryptoGlobalDefault: true
  CloudName: standalone.${CLOUD_DOMAIN}
  Debug: true
  DeploymentUser: $USER
  NtpServer: $NTP_SERVER
  # needed for vip & pacemaker
  KernelIpNonLocalBind: 1
  DockerInsecureRegistryAddress:
  - $CTLPLANE_IP:8787
  NeutronPublicInterface: $NEUTRON_INTERFACE
  # domain name used by the host
  NeutronDnsDomain: ${CLOUD_DOMAIN}
  # re-use ctlplane bridge for public net
  NeutronBridgeMappings: $BRIDGE_MAPPINGS
  NeutronPhysicalBridge: $BRIDGE
  NeutronFlatNetworks: $NEUTRON_FLAT_NETWORKS
  StandaloneEnableRoutedNetworks: false
  StandaloneHomeDir: $HOME
  InterfaceLocalMtu: ${INTERFACE_MTU}
  # Needed if running in a VM
  ValidateGatewaysIcmp: false
  ValidateControllersIcmp: false
  OctaviaAmphoraSshKeyFile: /root/.ssh/id_ecdsa.pub
  OctaviaGenerateCerts: true
  OctaviaLogOffload: true
  OctaviaForwardAllLogs: true
  StandaloneNetworkConfigTemplate: $HOME/standalone_net_config.j2
  ServiceNetMap:
    IronicNetwork: baremetal
    IronicInspectorNetwork: baremetal
  IronicInspectorSubnets:
  - ip_range: 172.20.1.190,172.20.1.199
    netmask: 255.255.255.0
    gateway: 172.20.1.1
    tag: baremetal
  IronicInspectorInterface: br-baremetal
  IronicCleaningDiskErase: metadata
EOF

CMD="openstack tripleo deploy"

CMD_ARGS+=" --templates /usr/share/openstack-tripleo-heat-templates"
CMD_ARGS+=" --local-ip=$CTLPLANE_IP/$CIDR"
CMD_ARGS+=" --control-virtual-ip=$CTLPLANE_VIP"
CMD_ARGS+=" --output-dir $HOME"
CMD_ARGS+=" --standalone-role Standalone"
CMD_ARGS+=" -r $HOME/Standalone.yaml"
CMD_ARGS+=" -n $HOME/network_data.yaml"

ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/standalone/standalone-tripleo.yaml"
ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml"
ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/deployed-network-environment.yaml"
ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/cinder-backup.yaml"
if [ "$COMPUTE_DRIVER" = "ironic" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/ironic-overcloud.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/ironic-inspector.yaml"
fi
if [ "$HEAT_ENABLED" = "true" ]; then
    cat <<EOF > enable_heat.yaml
resource_registry:
  OS::TripleO::Services::HeatApi: /usr/share/openstack-tripleo-heat-templates/deployment/heat/heat-api-container-puppet.yaml
  OS::TripleO::Services::HeatApiCfn: /usr/share/openstack-tripleo-heat-templates/deployment/heat/heat-api-cfn-container-puppet.yaml
  OS::TripleO::Services::HeatEngine: /usr/share/openstack-tripleo-heat-templates/deployment/heat/heat-engine-container-puppet.yaml
EOF
    ENV_ARGS+=" -e $HOME/enable_heat.yaml"
fi
if [ "$BARBICAN_ENABLED" = "true" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/barbican.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/barbican-backend-simple-crypto.yaml"
fi
if [ "$MANILA_ENABLED" = "true" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/manila-cephfsnative-config.yaml"
fi

if [ "$OCTAVIA_ENABLED" = "true" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/octavia.yaml"
fi
if [ "$TELEMETRY_ENABLED" = "true" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/enable-legacy-telemetry.yaml"
fi
if [ "$TLSE_ENABLED" = "true" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/ssl/tls-everywhere-endpoints-dns.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/haproxy-public-tls-certmonger.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/ssl/enable-internal-tls.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/ssl/enable-memcached-tls.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/ci/environments/standalone-ipa.yaml"
    export IPA_ADMIN_USER=admin
    export IPA_PRINCIPAL=$IPA_ADMIN_USER
    export IPA_ADMIN_PASSWORD=fce95318204114530f31f885c9df588f
    export IPA_PASSWORD=$IPA_ADMIN_PASSWORD
    #export CLOUD_DOMAIN=$CLOUD_DOMAIN
    export UNDERCLOUD_FQDN=standalone.$CLOUD_DOMAIN
    export IPA_DOMAIN=$CLOUD_DOMAIN
    export IPA_REALM=$(echo $IPA_DOMAIN | awk '{print toupper($0)}')
    export IPA_HOST=ipa.$IPA_DOMAIN
    export IPA_SERVER_HOSTNAME=$IPA_HOST
    mkdir /tmp/ipa-data
    podman run -d --name freeipa-server-container \
        --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
        --security-opt seccomp=unconfined \
        --ip 10.88.0.2 \
        -e IPA_SERVER_IP=10.88.0.2 \
        -e PASSWORD=$IPA_ADMIN_PASSWORD \
        -h $IPA_SERVER_HOSTNAME \
        --read-only --tmpfs /run --tmpfs /tmp \
        -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
        -v /tmp/ipa-data:/data:Z "$IPA_IMAGE" no-exit \
        -U -r $IPA_REALM --setup-dns --no-reverse --no-ntp \
        --no-dnssec-validation --auto-forwarders
    timeout 900s grep -qEi '(INFO The ipa-server-install command was successful|ERROR The ipa-server-install command failed)' <(tail -F /tmp/ipa-data/var/log/ipaserver-install.log)
    cat  <<EOF > /etc/resolv.conf
search ${CLOUD_DOMAIN}
nameserver 10.88.0.2
EOF
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    ansible-playbook /usr/share/ansible/tripleo-playbooks/undercloud-ipa-install.yaml
fi
ENV_ARGS+=" -e $HOME/standalone_parameters.yaml"
if [ "$EDPM_COMPUTE_CEPH_ENABLED" = "true" ] ; then
    CEPH_ARGS=${CEPH_ARGS:-"-e ~/deployed_ceph.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/cephadm/cephadm-rbd-only.yaml"}
    [[ "$MANILA_ENABLED" == "true" ]] && CEPH_ARGS+=' -e /usr/share/openstack-tripleo-heat-templates/environments/cephadm/ceph-mds.yaml'
    ENV_ARGS+=" ${CEPH_ARGS}"
fi
ENV_ARGS+=" -e $HOME/containers-prepare-parameters.yaml"
ENV_ARGS+=" -e $HOME/deployed_network.yaml"
if [ "$EDPM_COMPUTE_SRIOV_ENABLED" = "true" ] ; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/neutron-ovn-sriov.yaml"
    ENV_ARGS+=" -e $HOME/sriov_template.yaml"
fi

if [ "$SWIFT_REPLICATED" = "true" ]; then
cat <<EOF >> standalone_parameters.yaml
  SwiftReplicas: 3
  SwiftRawDisks: {"vdb": {}, "vdc": {}, "vdd": {}}
  SwiftUseLocalDir: false
EOF
fi

if [ "$EDPM_COMPUTE_DHCP_AGENT_ENABLED" = "true" ] ; then
    ENV_ARGS+=" -e $HOME/dhcp_agent_template.yaml"
fi

sudo ${CMD} ${CMD_ARGS} ${ENV_ARGS}
