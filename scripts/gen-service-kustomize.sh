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

# expect that the common.sh is in the same dir as the calling script
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
. ${SCRIPTPATH}/common.sh --source-only

if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

if [ -z "$KIND" ]; then
    echo "Please set SERVICE"; exit 1
fi

if [ -z "$SECRET" ]; then
    echo "Please set SECRET"; exit 1
fi

if [ -z "$DEPLOY_DIR" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ -n "$IPV6_ENABLED" ]; then
    echo CTLPLANE_IPV6_ADDRESS_PREFIX ${CTLPLANE_IPV6_ADDRESS_PREFIX}
    echo CTLPLANE_IPV6_GATEWAY ${CTLPLANE_IPV6_GATEWAY}
fi

REPLACEMENTS="" # will be populated with replacements for the service, if necessary
IMAGE=${IMAGE:-unused}
IMAGE_PATH=${IMAGE_PATH:-containerImage}
STORAGE_REQUEST=${STORAGE_REQUEST:-10G}
INTERFACE_MTU=${INTERFACE_MTU:-1500}
VLAN_START=${VLAN_START:-20}
VLAN_STEP=${VLAN_STEP:-1}

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

pushd ${DEPLOY_DIR}

cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
namespace: ${NAMESPACE}
labels:
  - pairs:
      created-by: install_yamls
patches:
- target:
    kind: ${KIND}
  patch: |-
    - op: replace
      path: /spec/secret
      value: ${SECRET}
    - op: replace
      path: /spec/storageClass
      value: ${STORAGE_CLASS}
EOF
if [[ "${KIND}" == "OpenStackControlPlane" && "${OPENSTACK_NEUTRON_CUSTOM_CONF}" != "" ]]; then
    cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/neutron/template/customServiceConfig
      value: |-
EOF
while IFS= read -r line; do
    echo "        $line" >>kustomization.yaml
done < ${OPENSTACK_NEUTRON_CUSTOM_CONF}
fi

IFS=',' read -ra IMAGES <<< "$IMAGE"
IFS=',' read -ra IMAGE_PATHS <<< "$IMAGE_PATH"

if [ ${#IMAGES[@]} != ${#IMAGE_PATHS[@]} ]; then
    echo "IMAGE and IMAGE_PATH should have the same length"; exit 1
fi

for (( i=0; i < ${#IMAGES[@]}; i++)); do
    SPEC_PATH=${IMAGE_PATHS[$i]}
    SPEC_VALUE=${IMAGES[$i]}

    if [ "${SPEC_VALUE}" != "unused" ]; then
        cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/${SPEC_PATH}
      value: ${SPEC_VALUE}
EOF
    fi
done

if [ -n "$NAME" ]; then
    cat <<EOF >>kustomization.yaml
    - op: replace
      path: /metadata/name
      value: ${NAME}
EOF
fi

if [ "${KIND}" == "OpenStackControlPlane" ]; then
   cat <<EOF>>kustomization.yaml
    - op: replace
      path: /spec/galera/templates/openstack/storageRequest
      value: ${STORAGE_REQUEST}
    - op: replace
      path: /spec/galera/templates/openstack-cell1/storageRequest
      value: ${STORAGE_REQUEST}
EOF
fi

if [ "${KIND}" == "Galera" ]; then
   cat <<EOF>>kustomization.yaml
    - op: replace
      path: /spec/storageRequest
      value: ${STORAGE_REQUEST}
EOF
fi

if [ "${KIND}" == "NetConfig" ]; then

    if [ -z "${IPV4_ENABLED}" ]; then
        IPV6_SUBNET_INDEX=0
    else
        IPV6_SUBNET_INDEX=1
    fi

    # Calculate VLAN IDs for networks that need them
    VLAN_INTERNALAPI=${VLAN_START}
    VLAN_STORAGE=$((VLAN_START + VLAN_STEP))
    VLAN_TENANT=$((VLAN_START + 2 * VLAN_STEP))
    VLAN_STORAGEMGMT=$((VLAN_START + 3 * VLAN_STEP))

    # Set MTU as requested
    cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/networks/0/mtu
      value: ${INTERFACE_MTU}
    - op: replace
      path: /spec/networks/1/mtu
      value: ${INTERFACE_MTU}
    - op: replace
      path: /spec/networks/2/mtu
      value: ${INTERFACE_MTU}
    - op: replace
      path: /spec/networks/3/mtu
      value: ${INTERFACE_MTU}
    - op: replace
      path: /spec/networks/4/mtu
      value: ${INTERFACE_MTU}
    - op: replace
      path: /spec/networks/5/mtu
      value: ${INTERFACE_MTU}
EOF

    # Generate ConfigMap with VLAN values and set up replacements for IPv4 subnets
    # This approach is necessary because:
    # 1. We cannot assume the order of the networks in the NetConfig CR, therefore we need to
    #    inject VLAN IDs based on the network name
    # 2. We cannot use name selectors in Kustomize patches, so they are not an option
    # 3. We could use replacements and "sourceValue"s, but they are not supported in
    #    the Kustomize version we are using, so that is not an option
    # 4. So instead we generate a local ConfigMap with the VLAN IDs and use it as a source
    #    for the replacements

    # Generate ConfigMap and replacements for IPv4 subnets if IPv4 is enabled
    if [ -n "${IPV4_ENABLED}" ]; then
    cat <<EOF >vlan-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  annotations:
    config.kubernetes.io/local-config: "true"
  name: vlan-config
data:
  internalapi: ${VLAN_INTERNALAPI}
  storage: ${VLAN_STORAGE}
  storagemgmt: ${VLAN_STORAGEMGMT}
  tenant: ${VLAN_TENANT}
EOF

    REPLACEMENTS="${REPLACEMENTS}
- source:
    kind: ConfigMap
    name: vlan-config
    fieldPath: data.internalapi
  targets:
  - select:
      kind: NetConfig
    fieldPaths:
    - spec.networks.[name=internalapi].subnets.0.vlan
- source:
    kind: ConfigMap
    name: vlan-config
    fieldPath: data.storage
  targets:
  - select:
      kind: NetConfig
    fieldPaths:
    - spec.networks.[name=storage].subnets.0.vlan
- source:
    kind: ConfigMap
    name: vlan-config
    fieldPath: data.storagemgmt
  targets:
  - select:
      kind: NetConfig
    fieldPaths:
    - spec.networks.[name=storagemgmt].subnets.0.vlan
- source:
    kind: ConfigMap
    name: vlan-config
    fieldPath: data.tenant
  targets:
  - select:
      kind: NetConfig
    fieldPaths:
    - spec.networks.[name=tenant].subnets.0.vlan"
    fi

    if [ -z "${IPV4_ENABLED}" ]; then
        # Delete IPv4 subnets if not enabled
        cat <<EOF >>kustomization.yaml
    - op: remove
      path: /spec/networks/0/subnets/0
    - op: remove
      path: /spec/networks/1/subnets/0
    - op: remove
      path: /spec/networks/2/subnets/0
    - op: remove
      path: /spec/networks/3/subnets/0
    - op: remove
      path: /spec/networks/4/subnets/0
    - op: remove
      path: /spec/networks/5/subnets/0
EOF
    fi

    if [ -n "${IPV6_ENABLED}" ]; then
    # Add IPv6 if enabled

        # CtlPlane
        cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/networks/0/subnets/${IPV6_SUBNET_INDEX}
      value:
          name: subnet$((${IPV6_SUBNET_INDEX}+1))
          allocationRanges:
          - end: ${CTLPLANE_IPV6_ADDRESS_PREFIX}120
            start: ${CTLPLANE_IPV6_ADDRESS_PREFIX}100
          - end: ${CTLPLANE_IPV6_ADDRESS_PREFIX}250
            start: ${CTLPLANE_IPV6_ADDRESS_PREFIX}200
          cidr: ${CTLPLANE_IPV6_ADDRESS_PREFIX}/64
          gateway: ${CTLPLANE_IPV6_GATEWAY}
EOF

        # InternalApi
        cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/networks/1/subnets/${IPV6_SUBNET_INDEX}
      value:
          name: subnet$((${IPV6_SUBNET_INDEX}+1))
          allocationRanges:
          - end: fd00:bbbb::250
            start: fd00:bbbb::100
          cidr: fd00:bbbb::/64
          vlan: ${VLAN_INTERNALAPI}
EOF

        # External
        cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/networks/2/subnets/${IPV6_SUBNET_INDEX}
      value:
          name: subnet$((${IPV6_SUBNET_INDEX}+1))
          allocationRanges:
          - end: fd00:ffff::250
            start: fd00:ffff::100
          cidr: fd00:ffff::/64
          gateway: fd00:ffff::1
EOF

        # Storage
        cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/networks/3/subnets/${IPV6_SUBNET_INDEX}
      value:
          name: subnet$((${IPV6_SUBNET_INDEX}+1))
          allocationRanges:
          - end: fd00:cccc::250
            start: fd00:cccc::100
          cidr: fd00:cccc::/64
          vlan: ${VLAN_STORAGE}
EOF

        # StorageMgmt
        cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/networks/4/subnets/${IPV6_SUBNET_INDEX}
      value:
          name: subnet$((${IPV6_SUBNET_INDEX}+1))
          allocationRanges:
          - end: fd00:eeee::250
            start: fd00:eeee::100
          cidr: fd00:eeee::/64
          vlan: ${VLAN_STORAGEMGMT}
EOF

        # Tenant
        cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/networks/5/subnets/${IPV6_SUBNET_INDEX}
      value:
          name: subnet$((${IPV6_SUBNET_INDEX}+1))
          allocationRanges:
          - end: fd00:dddd::250
            start: fd00:dddd::100
          cidr: fd00:dddd::/64
          vlan: ${VLAN_TENANT}
EOF

    fi
fi


if [ -n "$BGP" ]; then
    cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/networks/0
      value:
          name: BgpNet1
          dnsDomain: bgpnet1.example.com
          subnets:
          - name: subnet1
            allocationRanges:
            - end: 100.65.1.6
              start: 100.65.1.5
            cidr: 100.65.1.4/30
            gateway: 100.65.1.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.65.1.5
          - name: subnet2
            allocationRanges:
            - end: 100.65.2.6
              start: 100.65.2.5
            cidr: 100.65.2.4/30
            gateway: 100.65.2.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.65.2.5
          - name: subnet3
            allocationRanges:
            - end: 100.65.3.6
              start: 100.65.3.5
            cidr: 100.65.3.4/30
            gateway: 100.65.3.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.65.3.5
          - name: subnet4
            allocationRanges:
            - end: 100.65.4.6
              start: 100.65.4.5
            cidr: 100.65.4.4/30
            gateway: 100.65.4.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.65.4.5
    - op: add
      path: /spec/networks/1
      value:
          name: BgpNet2
          dnsDomain: bgpnet2.example.com
          subnets:
          - name: subnet1
            allocationRanges:
            - end: 100.64.1.6
              start: 100.64.1.5
            cidr: 100.64.1.4/30
            gateway: 100.64.1.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.64.1.5
          - name: subnet2
            allocationRanges:
            - end: 100.64.2.6
              start: 100.64.2.5
            cidr: 100.64.2.4/30
            gateway: 100.64.2.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.64.2.5
          - name: subnet3
            allocationRanges:
            - end: 100.64.3.6
              start: 100.64.3.5
            cidr: 100.64.3.4/30
            gateway: 100.64.3.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.64.3.5
          - name: subnet4
            allocationRanges:
            - end: 100.64.4.6
              start: 100.64.4.5
            cidr: 100.64.4.4/30
            gateway: 100.64.4.5
            routes:
            - destination: 0.0.0.0/0
              nexthop: 100.64.4.5
    - op: add
      path: /spec/networks/2
      value:
          name: BgpMainNet
          dnsDomain: bgpmainnet.example.com
          subnets:
          - name: subnet1
            cidr: 172.30.1.0/28
            allocationRanges:
            - end: 172.30.1.14
              start: 172.30.1.2
          - name: subnet2
            cidr: 172.30.2.0/28
            allocationRanges:
            - end: 172.30.2.14
              start: 172.30.2.2
          - name: subnet3
            cidr: 172.30.3.0/28
            allocationRanges:
            - end: 172.30.3.14
              start: 172.30.3.2
          - name: subnet4
            cidr: 172.30.4.0/28
            allocationRanges:
            - end: 172.30.4.14
              start: 172.30.4.2
    - op: add
      path: /spec/networks/3
      value:
          name: BgpMainNet6
          dnsDomain: bgpmainnet6.example.com
          subnets:
          - name: subnet1
            cidr: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0010/124
            allocationRanges:
            - end: f00d:f00d:f00d:f00d:f00d:f00d:f00d:001e
              start: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0012
          - name: subnet2
            cidr: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0020/124
            allocationRanges:
            - end: f00d:f00d:f00d:f00d:f00d:f00d:f00d:002e
              start: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0022
          - name: subnet3
            cidr: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0030/124
            allocationRanges:
            - end: f00d:f00d:f00d:f00d:f00d:f00d:f00d:003e
              start: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0032
          - name: subnet4
            cidr: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0040/124
            allocationRanges:
            - end: f00d:f00d:f00d:f00d:f00d:f00d:f00d:004e
              start: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0042
EOF
fi

if [[ "${KIND}" == "OpenStackControlPlane" && "${OVN_NICMAPPING}" == "true" ]]; then
cat <<EOF >>kustomization.yaml
- patch: |-
    apiVersion: core.openstack.org/v1beta1
    kind: ${KIND}
    metadata:
      name: unused
    spec:
      ovn:
        template:
          ovnController:
            nicMappings:
              datacentre: ${BRIDGE_NAME}
  target:
    kind: ${KIND}
EOF
fi

if [[ "${KIND}" == "OpenStackControlPlane" ]]; then
    if [ -z "${IPV4_ENABLED}" ]; then
        cat <<EOF >>kustomization.yaml
- target:
    kind: ${KIND}
  patch: |-
    - op: remove
      path: /spec/dns/template/options/0/values/0
EOF
    fi

    if [ -n "${IPV6_ENABLED}" ]; then
        cat <<EOF >>kustomization.yaml
- target:
    kind: ${KIND}
  patch: |-
    - op: add
      path: /spec/dns/template/options/0/values/0
      value: ${CTLPLANE_IPV6_DNS_SERVER}
EOF
    fi

    if [ -z "${IPV4_ENABLED}" ] && [ -n "${IPV6_ENABLED}" ]; then
        cat <<EOF >>kustomization.yaml
- target:
    kind: ${KIND}
  patch: |-
    - op: replace
      path: /spec/dns/template/override/service/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: ${CTLPLANE_IPV6_ADDRESS_PREFIX}80
    - op: replace
      path: /spec/glance/template/glanceAPIs/default/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/cinder/template/cinderAPI/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/barbican/template/barbicanAPI/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/designate/template/designateAPI/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/heat/template/heatAPI/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/heat/template/heatEngine/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/swift/template/swiftProxy/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/keystone/template/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/manila/template/manilaAPI/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/nova/template/apiServiceTemplate/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/nova/template/metadataServiceTemplate/override/service/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/neutron/template/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/placement/template/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80
    - op: replace
      path: /spec/rabbitmq/templates/rabbitmq/override/service/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::85
    - op: replace
      path: /spec/rabbitmq/templates/rabbitmq-cell1/override/service/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::86
EOF
    elif [ -n "${IPV4_ENABLED}" ] && [ -n "${IPV6_ENABLED}" ]; then
        # TODO: Add support for dual stack
        cat <<EOF >>kustomization.yaml
- target:
    kind: ${KIND}
  patch: |-
    - op: replace
      path: /spec/dns/template/override/service/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: ${CTLPLANE_IPV6_ADDRESS_PREFIX}80,${CTLPLANE_IP_ADDRESS_PREFIX}.80
    - op: replace
      path: /spec/glance/template/glanceAPIs/default/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/cinder/template/cinderAPI/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/barbican/template/barbicanAPI/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/designate/template/designateAPI/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/heat/template/heatAPI/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/heat/template/heatEngine/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/swift/template/swiftProxy/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/keystone/template/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/manila/template/manilaAPI/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/nova/template/apiServiceTemplate/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/nova/template/metadataServiceTemplate/override/service/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/neutron/template/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/placement/template/override/service/internal/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::80,172.17.0.80
    - op: replace
      path: /spec/rabbitmq/templates/rabbitmq/override/service/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::85,172.17.0.85
    - op: replace
      path: /spec/rabbitmq/templates/rabbitmq-cell1/override/service/metadata/annotations/metallb.universe.tf~1loadBalancerIPs
      value: fd00:bbbb::86,172.17.0.86
EOF
    fi
fi

# Add replacements if any were built
if [ -n "$REPLACEMENTS" ]; then
  cat <<EOF >>kustomization.yaml
replacements:
$REPLACEMENTS
EOF
fi

kustomization_add_resources

popd
