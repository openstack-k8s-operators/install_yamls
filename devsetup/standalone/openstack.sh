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
COMPUTE_DRIVER=${COMPUTE_DRIVER:-"libvirt"}
INTERFACE_MTU=${INTERFACE_MTU:-1500}

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
  CloudName: $CTLPLANE_IP
  Debug: true
  DeploymentUser: $USER
  NtpServer: $NTP_SERVER
  # needed for vip & pacemaker
  KernelIpNonLocalBind: 1
  DockerInsecureRegistryAddress:
  - $CTLPLANE_IP:8787
  NeutronPublicInterface: $NEUTRON_INTERFACE
  # domain name used by the host
  NeutronDnsDomain: localdomain
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
if [ "$COMPUTE_DRIVER" = "ironic" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/ironic-overcloud.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/ironic-inspector.yaml"
fi
ENV_ARGS+=" -e $HOME/standalone_parameters.yaml"
if [ "$EDPM_COMPUTE_CEPH_ENABLED" = "true" ] ; then
    CEPH_ARGS=${CEPH_ARGS:-"-e ~/deployed_ceph.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/cephadm/cephadm-rbd-only.yaml"}
    ENV_ARGS+=" ${CEPH_ARGS}"
fi
ENV_ARGS+=" -e $HOME/containers-prepare-parameters.yaml"
ENV_ARGS+=" -e $HOME/deployed_network.yaml"

sudo ${CMD} ${CMD_ARGS} ${ENV_ARGS}
