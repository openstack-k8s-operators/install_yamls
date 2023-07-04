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

# Use os-net-config to add VLAN interfaces which connect edpm-compute-0 to the isolated networks configured by install_yamls.

export GATEWAY=192.168.122.1
export CTLPLANE_IP=192.168.122.100
export INTERNAL_IP=$(sed -e 's/192.168.122/172.17.0/' <<<"$CTLPLANE_IP")
export STORAGE_IP=$(sed -e 's/192.168.122/172.18.0/' <<<"$CTLPLANE_IP")
export STORAGE_MGMT_IP=$(sed -e 's/192.168.122/172.20.0/' <<<"$CTLPLANE_IP")
export TENANT_IP=$(sed -e 's/192.168.122/172.19.0/' <<<"$CTLPLANE_IP")
export EXTERNAL_IP=$(sed -e 's/192.168.122/172.21.0/' <<<"$CTLPLANE_IP")

sudo mkdir -p /etc/os-net-config

cat << EOF | sudo tee /etc/os-net-config/config.yaml
network_config:
- type: ovs_bridge
  name: br-ctlplane
  mtu: 1500
  use_dhcp: false
  dns_servers:
  - $GATEWAY
  domain: []
  addresses:
  - ip_netmask: $CTLPLANE_IP/24
  routes:
  - ip_netmask: 0.0.0.0/0
    next_hop: $GATEWAY
  members:
  - type: interface
    name: nic1
    mtu: 1500
    # force the MAC address of the bridge to this interface
    primary: true

  # external
  - type: vlan
    mtu: 1500
    vlan_id: 44
    addresses:
    - ip_netmask: $EXTERNAL_IP/24
    routes: []

  # internal
  - type: vlan
    mtu: 1500
    vlan_id: 20
    addresses:
    - ip_netmask: $INTERNAL_IP/24
    routes: []

  # storage
  - type: vlan
    mtu: 1500
    vlan_id: 21
    addresses:
    - ip_netmask: $STORAGE_IP/24
    routes: []

  # storage_mgmt
  - type: vlan
    mtu: 1500
    vlan_id: 23
    addresses:
    - ip_netmask: $STORAGE_MGMT_IP/24
    routes: []

  # tenant
  - type: vlan
    mtu: 1500
    vlan_id: 22
    addresses:
    - ip_netmask: $TENANT_IP/24
    routes: []
EOF

cat << EOF | sudo tee /etc/cloud/cloud.cfg.d/99-edpm-disable-network-config.cfg
network:
  config: disabled
EOF

sudo systemctl enable network
sudo os-net-config -c /etc/os-net-config/config.yaml

# The isolated networks from os-net-config config file above will be lost when openstack tripleo deploy is run
# because the default os-net-config template only has the Neutron public interface as a member.
# To prevent this, copy the standalone.j2 template file (which retains the VLANs above) into tripleo-ansible's tripleo_network_config role.

sudo cp /tmp/standalone.j2 /usr/share/ansible/roles/tripleo_network_config/templates/standalone.j2

# Assign VIPs to the networks created when os-net-config was run. The tenant network on vlan22 does not require a VIP.

sudo ip addr add 172.17.0.2/32 dev vlan20
sudo ip addr add 172.18.0.2/32 dev vlan21
sudo ip addr add 172.20.0.2/32 dev vlan23
sudo ip addr add 172.21.0.2/32 dev vlan44
