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

function check_var_setted () {
  if [[ ! -v $1 ]]; then
    echo "Please set $1"; exit 1
  fi
}

check_var_setted DEPLOY_DIR

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

check_var_setted WORKERS
check_var_setted GATEWAY
check_var_setted INTERFACE
check_var_setted INTERFACE_DATA
check_var_setted INTERFACE_MANAGEMENT
check_var_setted INTERFACE_EXTERNAL
check_var_setted INTERFACE_MTU
check_var_setted INTERNALAPI_VLAN
check_var_setted STORAGE_VLAN
check_var_setted TENANT_VLAN
check_var_setted INTERNALAPI_NET
check_var_setted STORAGE_NET
check_var_setted TENANT_NET
check_var_setted DATA_NET

if [ -z "${DATA_NET}" ]; then
    echo "Please set DATA_NET"; exit 1
fi

echo DEPLOY_DIR ${DEPLOY_DIR}
echo WORKERS ${WORKERS}
echo INTERFACE ${INTERFACE}
echo INTERFACE_DATA ${INTERFACE_DATA}
echo INTERFACE_MANAGEMENT ${INTERFACE_MANAGEMENT}
echo INTERFACE_EXTERNAL ${INTERFACE_EXTERNAL}
echo INTERFACE_MTU ${INTERFACE_MTU}
echo INTERNALAPI_VLAN ${INTERNALAPI_VLAN}
echo STORAGE_VLAN ${STORAGE_VLAN}
echo TENANT_VLAN ${TENANT_VLAN}
echo INTERNALAPI_NET ${INTERNALAPI_NET}
echo STORAGE_NET ${STORAGE_NET}
echo TENANT_NET ${TENANT_NET}
echo NNCP_DATA_NET ${DATA_NET}

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
  nodeSelector:
    kubernetes.io/hostname: ${WORKER}
    node-role.kubernetes.io/worker: ""
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
        - ip: ${INTERNALAPI_NET}.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      name: ${INTERFACE_DATA}.${INTERNALAPI_VLAN}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE_DATA}
        id: ${INTERNALAPI_VLAN}
    - description: storage vlan interface
      ipv4:
        address:
        - ip: ${STORAGE_NET}.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      name: ${INTERFACE_MANAGEMENT}.${STORAGE_VLAN}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE_MANAGEMENT}
        id: ${STORAGE_VLAN}
    - description: tenant vlan interface
      ipv4:
        address:
        - ip: ${TENANT_NET}.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      name: ${INTERFACE_MANAGEMENT}.${TENANT_VLAN}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE_MANAGEMENT}
        id: ${TENANT_VLAN}
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
EOF_CAT

#TODO Regarding configuring interface data
#Look if it has an IP range which is not used
if [ $INTERFACE != $INTERFACE_DATA ]; then
  # I'm assuming that the data network on wallaby
  # deployment doesn't have DHCP enabled, which is the
  # case that I encountered.
  cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: Configuring ${INTERFACE_DATA}
      ipv4:
        address:
        - ip: ${DATA_NET}.${CTLPLANE_IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      mtu: ${INTERFACE_MTU}
      name: ${INTERFACE_DATA}
      state: up
      type: ethernet
EOF_CAT
fi


    IP_ADDRESS_SUFFIX=$((${IP_ADDRESS_SUFFIX}+1))
    CTLPLANE_IP_ADDRESS_SUFFIX=$((${CTLPLANE_IP_ADDRESS_SUFFIX}+1))
done
