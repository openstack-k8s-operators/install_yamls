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

openstack tripleo container image prepare default \
    --output-env-file $HOME/containers-prepare-parameters.yaml

export NEUTRON_INTERFACE=eth0
export CTLPLANE_IP=192.168.122.100
export CTLPLANE_VIP=192.168.122.99
export CIDR=24
export DNS_SERVERS=192.168.122.1
export GATEWAY=192.168.122.1
export BRIDGE="br-ctlplane"

cat <<EOF > standalone_parameters.yaml
parameter_defaults:
  CloudName: $CTLPLANE_IP
  ControlPlaneStaticRoutes:
    - ip_netmask: 0.0.0.0/0
      next_hop: $GATEWAY
      default: true
  Debug: true
  DeploymentUser: $USER
  DnsServers: $DNS_SERVERS
  NtpServer: $NTP_SERVER
  # needed for vip & pacemaker
  KernelIpNonLocalBind: 1
  DockerInsecureRegistryAddress:
  - $CTLPLANE_IP:8787
  NeutronPublicInterface: $NEUTRON_INTERFACE
  # domain name used by the host
  NeutronDnsDomain: localdomain
  # re-use ctlplane bridge for public net
  NeutronBridgeMappings: datacentre:$BRIDGE
  NeutronPhysicalBridge: $BRIDGE
  StandaloneEnableRoutedNetworks: false
  StandaloneHomeDir: $HOME
  InterfaceLocalMtu: 1500
  # Needed if running in a VM
  NovaComputeLibvirtType: qemu
  ValidateGatewaysIcmp: false
  ValidateControllersIcmp: false
EOF

sudo openstack tripleo deploy \
    --templates /usr/share/openstack-tripleo-heat-templates \
    --standalone-role Standalone \
    -e /usr/share/openstack-tripleo-heat-templates/environments/standalone/standalone-tripleo.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml \
    -e ~/containers-prepare-parameters.yaml \
    -e standalone_parameters.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/cephadm/cephadm-rbd-only.yaml \
    -e ~/deployed_ceph.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/deployed-network-environment.yaml \
    -e /tmp/deployed_network.yaml \
    -r /usr/share/openstack-tripleo-heat-templates/roles/Standalone.yaml \
    -n /tmp/network_data.yaml \
    --local-ip=$CTLPLANE_IP/$CIDR \
    --control-virtual-ip=$CTLPLANE_VIP \
    --output-dir $HOME
