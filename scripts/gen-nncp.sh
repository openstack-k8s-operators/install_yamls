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

if [ -z "${BRIDGE_NAME}" ]; then
    echo "Please set BRIDGE_NAME"; exit 1
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

if [ -n "$BGP" ]; then
if [ -z "${INTERFACE_BGP_1}" ]; then
    echo "Please set INTERFACE_BGP_1"; exit 1
fi

if [ -z "${INTERFACE_BGP_2}" ]; then
    echo "Please set INTERFACE_BGP_2"; exit 1
fi

if [ -z "${BGP_1_IP_ADDRESS}" ]; then
    echo "Please set BGP_1_IP_ADDRESS"; exit 1
fi

if [ -z "${BGP_2_IP_ADDRESS}" ]; then
    echo "Please set BGP_2_IP_ADDRESS"; exit 1
fi
fi

echo DEPLOY_DIR ${DEPLOY_DIR}
echo WORKERS ${WORKERS}
echo INTERFACE ${INTERFACE}
echo BRIDGE_NAME ${BRIDGE_NAME}
echo INTERFACE_BGP_1 ${INTERFACE_BGP_1}
echo INTERFACE_BGP_2 ${INTERFACE_BGP_2}
echo INTERFACE_MTU ${INTERFACE_MTU}
echo VLAN_START ${VLAN_START}
echo VLAN_STEP ${VLAN_STEP}
if [ -n "$IPV4_ENABLED" ]; then
echo CTLPLANE_IP_ADDRESS_PREFIX ${CTLPLANE_IP_ADDRESS_PREFIX}
echo CTLPLANE_IP_ADDRESS_SUFFIX ${CTLPLANE_IP_ADDRESS_SUFFIX}
echo GATEWAY ${GATEWAY}
echo DNS_SERVER ${DNS_SERVER}
fi
if [ -n "$IPV6_ENABLED" ]; then
echo CTLPLANE_IPV6_ADDRESS_PREFIX ${CTLPLANE_IPV6_ADDRESS_PREFIX}
echo CTLPLANE_IPV6_ADDRESS_SUFFIX ${CTLPLANE_IPV6_ADDRESS_SUFFIX}
echo GATEWAY_IPV6 ${GATEWAY_IPV6}
echo DNS_SERVER_IPV6 ${DNS_SERVER_IPV6}
fi
if [ -n "$BGP" ]; then
echo INTERFACE_BGP_1 ${INTERFACE_BGP_1}
echo INTERFACE_BGP_2 ${INTERFACE_BGP_2}
echo BGP_1_IP_ADDRESS ${BGP_1_IP_ADDRESS}
echo BGP_2_IP_ADDRESS ${BGP_2_IP_ADDRESS}
fi

# Use different suffix for other networks as the sample netconfig
# we use starts with .10
IP_ADDRESS_SUFFIX=5
IPV6_ADDRESS_SUFFIX=5
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
EOF_CAT

    #
    # DNS Resolver
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    dns-resolver:
      config:
        search: []
        server:
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
        - ${DNS_SERVER}
EOF_CAT
    fi
    if [ -n "$IPV6_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
        - ${DNS_SERVER_IPV6}
EOF_CAT
    fi

    #
    # Routes
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    routes:
      config:
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      - destination: 0.0.0.0/0
        next-hop-address: ${GATEWAY}
        next-hop-interface: ${BRIDGE_NAME}
        metric: 101
EOF_CAT
    fi
    if [ -n "$IPV6_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      - destination: ::/0
        next-hop-address: ${GATEWAY_IPV6}
        next-hop-interface: ${BRIDGE_NAME}
EOF_CAT
    fi
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    interfaces:
EOF_CAT

    #
    # internalapi VLAN interface
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: internalapi vlan interface
      name: ${INTERFACE}.${VLAN_START}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${VLAN_START}
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        address:
        - ip: 172.17.0.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
EOF_CAT
    else
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        enabled: false
EOF_CAT
    fi
    if [ -n "$IPV6_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv6:
        address:
        - ip: fd00:bbbb::${IPV6_ADDRESS_SUFFIX}
          prefix-length: 64
        enabled: true
        dhcp: false
        autoconf: false
EOF_CAT
    else
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv6:
        enabled: false
EOF_CAT
    fi

    #
    # storage VLAN interface
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: storage vlan interface
      name: ${INTERFACE}.$((${VLAN_START}+${VLAN_STEP}))
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: $((${VLAN_START}+${VLAN_STEP}))
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        address:
        - ip: 172.18.0.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
EOF_CAT
    else
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        enabled: false
EOF_CAT
    fi
    if [ -n "$IPV6_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv6:
        address:
        - ip: fd00:cccc::${IPV6_ADDRESS_SUFFIX}
          prefix-length: 64
        enabled: true
        dhcp: false
        autoconf: false
EOF_CAT
    else
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv6:
        enabled: false
EOF_CAT
    fi

    #
    # tenant VLAN interface
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: tenant vlan interface
      name: ${INTERFACE}.$((${VLAN_START}+$((${VLAN_STEP}*2))))
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: $((${VLAN_START}+$((${VLAN_STEP}*2))))
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        address:
        - ip: 172.19.0.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
EOF_CAT
    else
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        enabled: false
EOF_CAT
    fi
    if [ -n "$IPV6_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv6:
        address:
        - ip: fd00:dddd::${IPV6_ADDRESS_SUFFIX}
          prefix-length: 64
        enabled: true
        dhcp: false
        autoconf: false
EOF_CAT
    else
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv6:
        enabled: false
EOF_CAT
    fi

    #
    # ctlplane interface (untagged)
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: Configuring Bridge ${BRIDGE_NAME} with interface ${INTERFACE}
      name: ${BRIDGE_NAME}
      mtu: ${INTERFACE_MTU}
      type: linux-bridge
      state: up
      bridge:
        options:
          stp:
            enabled: false
        port:
          - name: ${INTERFACE}
            vlan: {}
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        address:
        - ip: ${CTLPLANE_IP_ADDRESS_PREFIX}.${CTLPLANE_IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
EOF_CAT
    else
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        enabled: false
EOF_CAT
    fi
    if [ -n "$IPV6_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv6:
        address:
        - ip: ${CTLPLANE_IPV6_ADDRESS_PREFIX}${CTLPLANE_IPV6_ADDRESS_SUFFIX}
          prefix-length: 64
        enabled: true
        dhcp: false
        autoconf: false
EOF_CAT
    else
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv6:
        enabled: false
EOF_CAT
    fi
    if [ -n "$BGP" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: Configuring ${INTERFACE_BGP_1}
      ipv4:
        address:
        - ip: ${BGP_1_IP_ADDRESS}
          prefix-length: 30
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      mtu: ${INTERFACE_MTU}
      name: ${INTERFACE_BGP_1}
      state: up
      type: ethernet
    - description: Configuring ${INTERFACE_BGP_2}
      ipv4:
        address:
        - ip:  ${BGP_2_IP_ADDRESS}
          prefix-length: 30
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      mtu: ${INTERFACE_MTU}
      name: ${INTERFACE_BGP_2}
      state: up
      type: ethernet
    - description: Configuring lo
      ipv4:
        address:
          - ip: ${LO_IP_ADDRESS}
            prefix-length: 32
        enabled: true
        dhcp: false
      ipv6:
        address:
          - ip: ${LO_IP6_ADDRESS}
            prefix-length: 128
        enabled: true
        dhcp: false
      name: lo
      mtu: 65536
      state: up
EOF_CAT
    fi
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
  nodeSelector:
    kubernetes.io/hostname: ${WORKER}
    node-role.kubernetes.io/worker: ""
EOF_CAT

    IP_ADDRESS_SUFFIX=$((${IP_ADDRESS_SUFFIX}+1))
    IPV6_ADDRESS_SUFFIX=$((${IPV6_ADDRESS_SUFFIX}+1))
    CTLPLANE_IP_ADDRESS_SUFFIX=$((${CTLPLANE_IP_ADDRESS_SUFFIX}+1))
    CTLPLANE_IPV6_ADDRESS_SUFFIX=$((${CTLPLANE_IPV6_ADDRESS_SUFFIX}+1))
done
