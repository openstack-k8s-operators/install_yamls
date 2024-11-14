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

check_var_set INTERFACE
check_var_set BRIDGE_NAME
check_var_set VLAN_START
check_var_set VLAN_STEP

if [ -z "$IPV4_ENABLED" ] && [ -z "$IPV6_ENABLED" ]; then
    echo "Please enable either IPv4 or IPv6 by setting IPV4_ENABLED or IPV6_ENABLED"; exit 1
fi

if [ -n "$IPV4_ENABLED" ] && [ -n "$IPV6_ENABLED" ]; then
    echo "Dual stack not supported, cannot enable both IPv4 and IPv6"; exit 1
fi

if [ -n "$IPV4_ENABLED" ]; then
    check_var_set INTERNALAPI_PREFIX
    check_var_set STORAGE_PREFIX
    check_var_set STORAGEMGMT_PREFIX
    check_var_set TENANT_PREFIX
    check_var_set DESIGNATE_PREFIX
fi

echo DEPLOY_DIR ${DEPLOY_DIR}
echo INTERFACE ${INTERFACE}
echo VLAN_START ${VLAN_START}
echo VLAN_STEP ${VLAN_STEP}
if [ -n "$IPV4_ENABLED" ]; then
    echo CTLPLANE_IP_ADDRESS_PREFIX ${CTLPLANE_IP_ADDRESS_PREFIX}
    echo CTLPLANE_IP_ADDRESS_SUFFIX ${CTLPLANE_IP_ADDRESS_SUFFIX}
    echo "INTERNALAPI_PREFIX ${INTERNALAPI_PREFIX}"
    echo "STORAGE_PREFIX ${STORAGE_PREFIX}"
    echo "STORAGEMGMT_PREFIX ${STORAGEMGMT_PREFIX}"
    echo "TENANT_PREFIX ${TENANT_PREFIX}"
    echo "DESIGNATE_PREFIX ${DESIGNATE_PREFIX}"
fi
if [ -n "$IPV6_ENABLED" ]; then
    echo CTLPLANE_IPV6_ADDRESS_PREFIX ${CTLPLANE_IPV6_ADDRESS_PREFIX}
    echo CTLPLANE_IPV6_ADDRESS_SUFFIX ${CTLPLANE_IPV6_ADDRESS_SUFFIX}
fi

cat > ${DEPLOY_DIR}/ctlplane.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: ctlplane
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "ctlplane",
      "type": "macvlan",
      "master": "${BRIDGE_NAME}",
      "ipam": {
        "type": "whereabouts",
EOF_CAT
if [ -n "$IPV4_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/ctlplane.yaml <<EOF_CAT
        "range": "${CTLPLANE_IP_ADDRESS_PREFIX}.0/24",
        "range_start": "${CTLPLANE_IP_ADDRESS_PREFIX}.30",
        "range_end": "${CTLPLANE_IP_ADDRESS_PREFIX}.70"
EOF_CAT
elif [ -n "$IPV6_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/ctlplane.yaml <<EOF_CAT
        "range": "${CTLPLANE_IPV6_ADDRESS_PREFIX}0/64",
        "range_start": "${CTLPLANE_IPV6_ADDRESS_PREFIX}30",
        "range_end": "${CTLPLANE_IPV6_ADDRESS_PREFIX}70"
EOF_CAT
fi
cat >> ${DEPLOY_DIR}/ctlplane.yaml <<EOF_CAT
      }
    }
EOF_CAT

cat > ${DEPLOY_DIR}/internalapi.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: internalapi
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "internalapi",
      "type": "macvlan",
      "master": "${INTERFACE}.${VLAN_START}",
      "ipam": {
        "type": "whereabouts",
EOF_CAT
if [ -n "$IPV4_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/internalapi.yaml <<EOF_CAT
        "range": "${INTERNALAPI_PREFIX}.0/24",
        "range_start": "${INTERNALAPI_PREFIX}.30",
        "range_end": "${INTERNALAPI_PREFIX}.70"
EOF_CAT
elif [ -n "$IPV6_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/internalapi.yaml <<EOF_CAT
        "range": "fd00:bbbb::/64",
        "range_start": "fd00:bbbb::30",
        "range_end": "fd00:bbbb::70"
EOF_CAT
fi
cat >> ${DEPLOY_DIR}/internalapi.yaml <<EOF_CAT
      }
    }
EOF_CAT

cat > ${DEPLOY_DIR}/storage.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: storage
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "storage",
      "type": "macvlan",
      "master": "${INTERFACE}.$((${VLAN_START}+${VLAN_STEP}))",
      "ipam": {
        "type": "whereabouts",
EOF_CAT
if [ -n "$IPV4_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/storage.yaml <<EOF_CAT
        "range": "${STORAGE_PREFIX}.0/24",
        "range_start": "${STORAGE_PREFIX}.30",
        "range_end": "${STORAGE_PREFIX}.70"
EOF_CAT
elif [ -n "$IPV6_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/storage.yaml <<EOF_CAT
        "range": "fd00:cccc::/64",
        "range_start": "fd00:cccc::30",
        "range_end": "fd00:cccc::70"
EOF_CAT
fi
cat >> ${DEPLOY_DIR}/storage.yaml <<EOF_CAT
      }
    }
EOF_CAT

cat > ${DEPLOY_DIR}/tenant.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: tenant
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "tenant",
      "type": "macvlan",
      "master": "${INTERFACE}.$((${VLAN_START}+$((${VLAN_STEP}*2))))",
      "ipam": {
        "type": "whereabouts",
EOF_CAT
if [ -n "$IPV4_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/tenant.yaml <<EOF_CAT
        "range": "${TENANT_PREFIX}.0/24",
        "range_start": "${TENANT_PREFIX}.30",
        "range_end": "${TENANT_PREFIX}.70"
EOF_CAT
elif [ -n "$IPV6_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/tenant.yaml <<EOF_CAT
        "range": "fd00:dddd::/64",
        "range_start": "fd00:dddd::30",
        "range_end": "fd00:dddd::70"
EOF_CAT
fi
cat >> ${DEPLOY_DIR}/tenant.yaml <<EOF_CAT
      }
    }
EOF_CAT

cat > ${DEPLOY_DIR}/datacentre.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: datacentre
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "datacentre",
      "type": "bridge",
      "bridge": "${BRIDGE_NAME}",
      "ipam": {}
    }
EOF_CAT

cat > ${DEPLOY_DIR}/storagemgmt.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: storagemgmt
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "storagemgmt",
      "type": "macvlan",
      "master": "${INTERFACE}.$((${VLAN_START}+${VLAN_STEP}*3))",
      "ipam": {
        "type": "whereabouts",
EOF_CAT
if [ -n "$IPV4_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/storagemgmt.yaml <<EOF_CAT
        "range": "${STORAGEMGMT_PREFIX}.0/24",
        "range_start": "${STORAGEMGMT_PREFIX}.30",
        "range_end": "${STORAGEMGMT_PREFIX}.70"
EOF_CAT
elif [ -n "$IPV6_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/storagemgmt.yaml <<EOF_CAT
        "range": "fd00:dede::/64",
        "range_start": "fd00:dede::30",
        "range_end": "fd00:dede::70"
EOF_CAT
fi
cat >> ${DEPLOY_DIR}/storagemgmt.yaml <<EOF_CAT
      }
    }
EOF_CAT

cat > ${DEPLOY_DIR}/octavia.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: octavia
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "octavia",
      "type": "bridge",
      "bridge": "octbr",
      "ipam": {
        "type": "whereabouts",
EOF_CAT
if [ -n "$IPV4_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/octavia.yaml <<EOF_CAT
        "range": "172.23.0.0/24",
        "range_start": "172.23.0.30",
        "range_end": "172.23.0.70",
        "routes": [
           {
             "dst": "172.24.0.0/16",
             "gw" : "172.23.0.150"
           }
         ]
EOF_CAT
elif [ -n "$IPV6_ENABLED" ]; then
    cat >> ${DEPLOY_DIR}/octavia.yaml <<EOF_CAT
        "range": "fd00:eeee::/64",
        "range_start": "fd00:eeee::30",
        "range_end": "fd00:eeee::70",
        "routes": [
           {
             "dst": "fd6c:6261:6173:0001::/64",
             "gw" : "fd00:eeee::0096"
           }
         ]
EOF_CAT
fi
cat >> ${DEPLOY_DIR}/octavia.yaml <<EOF_CAT
      }
    }
EOF_CAT

cat > ${DEPLOY_DIR}/designate.yaml <<EOF_CAT
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: designate
  namespace: ${NAMESPACE}
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "designate",
      "type": "macvlan",
      "master": "${INTERFACE}.$((${VLAN_START}+${VLAN_STEP}*5))",
      "ipam": {
        "type": "whereabouts",
        "range": "172.28.0.0/24",
        "range_start": "172.28.0.30",
        "range_end": "172.28.0.70"
      }
    }
EOF_CAT

if [ -n "$INTERFACE_BGP_1" ]; then
    cat > ${DEPLOY_DIR}/bgpnet1.yaml <<EOF_CAT
    apiVersion: k8s.cni.cncf.io/v1
    kind: NetworkAttachmentDefinition
    metadata:
      name: bgpnet1
      namespace: openstack
    spec:
      config: |
        {
          "cniVersion": "0.3.1",
          "name": "bgpnet1",
          "type": "interface",
          "master": "${INTERFACE_BGP_1}",
          "ipam": {
            "type": "whereabouts",
            "range": "100.65.4.0/30",
            "range_start": "100.65.4.1",
            "range_end": "100.65.4.2"
          }
        }
EOF_CAT
fi

if [ -n "$INTERFACE_BGP_2" ]; then
    cat > ${DEPLOY_DIR}/bgpnet2.yaml <<EOF_CAT
    apiVersion: k8s.cni.cncf.io/v1
    kind: NetworkAttachmentDefinition
    metadata:
      name: bgpnet2
      namespace: openstack
    spec:
      config: |
        {
          "cniVersion": "0.3.1",
          "name": "bgpnet2",
          "type": "interface",
          "master": "${INTERFACE_BGP_2}",
          "ipam": {
            "type": "whereabouts",
            "range": "100.64.4.0/30",
            "range_start": "100.64.4.1",
            "range_end": "100.64.4.2"
          }
        }
EOF_CAT
fi
