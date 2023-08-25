#!/bin/bash
#
# Copyright 2022 Red Hat Inc.
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

if [ -z "${DEPLOY_DIR}" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

if [ -z "${WORKERS}" ]; then
    echo "Please set WORKERS"; exit 1
fi

if [ -z "${INTERFACE}" ]; then
    echo "Please set INTERFACE"; exit 1
fi

if [ -z "${INTERFACE_MTU}" ]; then
    echo "Please set INTERFACE_MTU"; exit 1
fi

if [ -z "${VLAN_START}" ]; then
    echo "Please set VLAN_START"; exit 1
fi

if [ -z "${VLAN_STEP}" ]; then
    echo "Please set VLAN_STEP"; exit 1
fi

echo DEPLOY_DIR ${DEPLOY_DIR}
echo WORKERS ${WORKERS}
echo INTERFACE ${INTERFACE}
echo INTERFACE_MTU ${INTERFACE_MTU}
echo VLAN_START ${VLAN_START}
echo VLAN_STEP ${VLAN_STEP}

# Use different suffix for other networks as the sample netconfig
# we use starts with .10
IP_ADDRESS_SUFFIX=5
for WORKER in ${WORKERS}; do
  cat > ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  labels:
    osp/interface: ${INTERFACE}
  name: ${INTERFACE}-${WORKER}
spec:
  desiredState:
    dns-resolver:
      config:
        search: []
        server:
        - ${DNS_SERVER}
    routes:
      config:
      - destination: 0.0.0.0/0
        next-hop-address: ${GATEWAY}
        next-hop-interface: ${INTERFACE}
    interfaces:
    - description: internalapi vlan interface
      ipv4:
        address:
        - ip: 172.17.0.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      name: ${INTERFACE}.${VLAN_START}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${VLAN_START}
    - description: storage vlan interface
      ipv4:
        address:
        - ip: 172.18.0.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      name: ${INTERFACE}.$((${VLAN_START}+${VLAN_STEP}))
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: $((${VLAN_START}+${VLAN_STEP}))
    - description: tenant vlan interface
      ipv4:
        address:
        - ip: 172.19.0.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      name: ${INTERFACE}.$((${VLAN_START}+$((${VLAN_STEP}*2))))
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: $((${VLAN_START}+$((${VLAN_STEP}*2))))
    - description: Configuring ${INTERFACE}
      ipv4:
        address:
        - ip: ${CTLPLANE_IP_ADDRESS_PREFIX}.${CTLPLANE_IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      mtu: ${INTERFACE_MTU}
      name: ${INTERFACE}
      state: up
      type: ethernet
  nodeSelector:
    kubernetes.io/hostname: ${WORKER}
    node-role.kubernetes.io/worker: ""
EOF_CAT

    IP_ADDRESS_SUFFIX=$((${IP_ADDRESS_SUFFIX}+1))
    CTLPLANE_IP_ADDRESS_SUFFIX=$((${CTLPLANE_IP_ADDRESS_SUFFIX}+1))
done
