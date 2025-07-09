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

function check_var_set {
    if [[ ! -v $1 ]]; then
        echo "Please set $1"; exit 1
    fi
}

check_var_set DEPLOY_DIR

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

check_var_set WORKERS
check_var_set INTERFACE
check_var_set BRIDGE_NAME
check_var_set INTERFACE_MTU
check_var_set VLAN_START
check_var_set VLAN_STEP
check_var_set VLAN_STEP
check_var_set INTERNALAPI_PREFIX
check_var_set STORAGE_PREFIX
check_var_set STORAGEMGMT_PREFIX
check_var_set TENANT_PREFIX
check_var_set DESIGNATE_PREFIX
check_var_set DESIGNATE_EXT_PREFIX
if [ -n "$BGP" ]; then
    check_var_set INTERFACE_BGP_1
    check_var_set INTERFACE_BGP_2
    check_var_set BGP_1_IP_ADDRESS
    check_var_set BGP_2_IP_ADDRESS
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
echo STORAGE_MACVLAN ${STORAGE_MACVLAN}
if [ -n "$IPV4_ENABLED" ]; then
echo CTLPLANE_IP_ADDRESS_PREFIX ${CTLPLANE_IP_ADDRESS_PREFIX}
echo CTLPLANE_IP_ADDRESS_SUFFIX ${CTLPLANE_IP_ADDRESS_SUFFIX}
fi
if [ -n "$IPV6_ENABLED" ]; then
echo CTLPLANE_IPV6_ADDRESS_PREFIX ${CTLPLANE_IPV6_ADDRESS_PREFIX}
echo CTLPLANE_IPV6_ADDRESS_SUFFIX ${CTLPLANE_IPV6_ADDRESS_SUFFIX}
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

# Clean up pre-existing files to avoid failed nncp
rm --force ${DEPLOY_DIR}/*_nncp.yaml
# vlan ids
internalapi_vlan_id=$VLAN_START
storage_vlan_id=$((VLAN_START + VLAN_STEP))
tenant_vlan_id=$((${VLAN_START}+$((${VLAN_STEP}*2))))
storagemgmt_vlan_id=$((${VLAN_START}+$((${VLAN_STEP}*3))))
octavia_vlan_id=$((${VLAN_START}+$((${VLAN_STEP}*4))))
designate_vlan_id=$((${VLAN_START}+$((${VLAN_STEP}*5))))
designate_ext_vlan_id=$((${VLAN_START}+$((${VLAN_STEP}*6))))

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
    if [ -n "$NNCP_ADDITIONAL_HOST_ROUTES" ] || [ -n "$NNCP_INTERNALAPI_HOST_ROUTES" ] || \
       [ -n "$NNCP_STORAGE_HOST_ROUTES" ] || [ -n "$NNCP_STORAGEMGMT_HOST_ROUTES" ] || \
       [ -n "$NNCP_TENANT_HOST_ROUTES" ]; then
    #
    # Host Routes
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    routes:
      config:
EOF_CAT
    fi
        if [ -n "$NNCP_ADDITIONAL_HOST_ROUTES" ]; then
            for route in $NNCP_ADDITIONAL_HOST_ROUTES; do
                cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      - destination: ${route}
        next-hop-interface: ${BRIDGE_NAME}
EOF_CAT
            done
        fi
        if [ -n "$NNCP_INTERNALAPI_HOST_ROUTES" ]; then
            for internalapi_route in $NNCP_INTERNALAPI_HOST_ROUTES; do
                cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      - destination: ${internalapi_route}
        next-hop-interface: ${INTERFACE}.${internalapi_vlan_id}
EOF_CAT
            done
        fi
        if [ -n "$NNCP_STORAGE_HOST_ROUTES" ]; then
            for storage_route in $NNCP_STORAGE_HOST_ROUTES; do
                cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      - destination: ${storage_route}
        next-hop-interface: ${INTERFACE}.${storage_vlan_id}
EOF_CAT
            done
        fi
        if [ -n "$NNCP_STORAGEMGMT_HOST_ROUTES" ]; then
            for storagemgmt_route in $NNCP_STORAGEMGMT_HOST_ROUTES; do
                cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      - destination: ${storagemgmt_route}
        next-hop-interface: ${INTERFACE}.${storagemgmt_vlan_id}
EOF_CAT
            done
        fi
        if [ -n "$NNCP_TENANT_HOST_ROUTES" ]; then
            for tenant_route in $NNCP_TENANT_HOST_ROUTES; do
              cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      - destination: ${tenant_route}
        next-hop-interface: ${INTERFACE}.${tenant_vlan_id}
EOF_CAT
            done
        fi
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    interfaces:
EOF_CAT

    #
    # internalapi VLAN interface
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: internalapi vlan interface
      name: ${INTERFACE}.${internalapi_vlan_id}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${internalapi_vlan_id}
        reorder-headers: true
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        address:
        - ip: ${INTERNALAPI_PREFIX}.${IP_ADDRESS_SUFFIX}
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

    cat >> "${DEPLOY_DIR}/${WORKER}_nncp.yaml" <<EOF_CAT
    - description: storage vlan interface
      name: ${INTERFACE}.${storage_vlan_id}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${storage_vlan_id}
        reorder-headers: true
EOF_CAT

    if [ -n "${STORAGE_MACVLAN}" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        enabled: false
      ipv6:
        enabled: false
    - description: macvlan interface for storage NW
      name: storage
      state: up
      type: mac-vlan
      mac-vlan:
        base-iface: ${INTERFACE}.${storage_vlan_id}
        mode: bridge
EOF_CAT
    fi

    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        address:
        - ip: ${STORAGE_PREFIX}.${IP_ADDRESS_SUFFIX}
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
      name: ${INTERFACE}.${tenant_vlan_id}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${tenant_vlan_id}
        reorder-headers: true
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        address:
        - ip: ${TENANT_PREFIX}.${IP_ADDRESS_SUFFIX}
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
    # storagemgmt VLAN interface
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: storagemgmt vlan interface
      name: ${INTERFACE}.${storagemgmt_vlan_id}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${storagemgmt_vlan_id}
        reorder-headers: true
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        address:
        - ip: ${STORAGEMGMT_PREFIX}.${IP_ADDRESS_SUFFIX}
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
        - ip: fd00:dede::${IPV6_ADDRESS_SUFFIX}
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
    # octavia-vlan-link VLAN interface and bridge. Note that
    # octavia only requires L2 connectivity at the host level
    # Address management, etc. is unnecessary.
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: Octavia vlan host interface
      name: ${INTERFACE}.${octavia_vlan_id}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${octavia_vlan_id}
    - bridge:
        options:
          stp:
            enabled: false
        port:
          - name: ${INTERFACE}.${octavia_vlan_id}
      description: Configuring bridge octbr
      mtu: 1500
      name: octbr
      state: up
      type: linux-bridge
EOF_CAT

    #
    # designate VLAN interface
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: designate vlan interface
      name: ${INTERFACE}.${designate_vlan_id}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${designate_vlan_id}
        reorder-headers: true
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        address:
        - ip: ${DESIGNATE_PREFIX}.${IP_ADDRESS_SUFFIX}
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
        - ip: fd00:eded::${IPV6_ADDRESS_SUFFIX}
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
    # designate external VLAN interface
    #
    cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
    - description: designate external vlan interface
      name: ${INTERFACE}.${designate_ext_vlan_id}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${designate_ext_vlan_id}
        reorder-headers: true
EOF_CAT
    if [ -n "$IPV4_ENABLED" ]; then
        cat >> ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
      ipv4:
        address:
        - ip: ${DESIGNATE_EXT_PREFIX}.${IP_ADDRESS_SUFFIX}
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
        - ip: fd00:eaea::${IPV6_ADDRESS_SUFFIX}
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
