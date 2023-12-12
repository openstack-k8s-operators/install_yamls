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

# expect that the common.sh is in the same dir as the calling script
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
. ${SCRIPTPATH}/common.sh --source-only

if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

if [ -z "$KIND" ]; then
    echo "Please set SERVICE"; exit 1
fi

if [ -z "$DEPLOY_DIR" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

NAME=${KIND,,}

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

pushd ${DEPLOY_DIR}

cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
namespace: ${NAMESPACE}
patches:
- target:
    kind: ${KIND}
  patch: |-
    - op: replace
      path: /spec/preProvisioned
      value: true
    - op: replace
      path: /spec/nodes/edpm-compute-0/ansible/ansibleHost
      value: ${EDPM_COMPUTE_IP}
    - op: replace
      path: /spec/nodes/edpm-compute-0/networks
      value:
        - name: CtlPlane
          subnetName: subnet1
          defaultRoute: true
          fixedIP: ${EDPM_COMPUTE_IP}
        - name: InternalApi
          subnetName: subnet1
        - name: Storage
          subnetName: subnet1
        - name: Tenant
          subnetName: subnet1
EOF

if [ -n "$BGP" ]; then
cat <<EOF >>kustomization.yaml
        - name: BgpNet1
          subnetName: subnet1
          fixedIP: 100.65.1.6
        - name: BgpNet2
          subnetName: subnet1
          fixedIP: 100.64.1.6
        - name: BgpMainNet
          subnetName: subnet1
          fixedIP: 172.30.1.2
        - name: BgpMainNet6
          subnetName: subnet1
          fixedIP: f00d:f00d:f00d:f00d:f00d:f00d:f00d:0012
EOF
fi

cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/services/0
      value: repo-setup
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/timesync_ntp_servers
      value:
        - {hostname: ${EDPM_NTP_SERVER}}
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/neutron_public_interface_name
      value: ${EDPM_NETWORK_INTERFACE_NAME}
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/registry_url
      value: ${EDPM_REGISTRY_URL}
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/image_prefix
      value: ${EDPM_CONTAINER_PREFIX}
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/image_tag
      value: ${EDPM_CONTAINER_TAG}
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/edpm_sshd_allowed_ranges
      value: ${EDPM_SSHD_ALLOWED_RANGES}
    - op: add
      path: /spec/env/0
      value: {"name": "ANSIBLE_CALLBACKS_ENABLED", "value": "profile_tasks"}
    - op: replace
      path: /spec/nodeTemplate/ansibleSSHPrivateKeySecret
      value: ${EDPM_ANSIBLE_SECRET}
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleUser
      value: ${EDPM_ANSIBLE_USER:-"cloud-admin"}
EOF

if oc get pvc ansible-ee-logs -n ${NAMESPACE} 2>&1 1>/dev/null; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/nodeTemplate/extraMounts
      value:
        - extraVolType: Logs
          volumes:
          - name: ansible-logs
            persistentVolumeClaim:
              claimName: ansible-ee-logs
          mounts:
          - name: ansible-logs
            mountPath: "/runner/artifacts"
EOF
fi
if [ "$EDPM_TOTAL_NODES" -gt 1 ]; then
    for INDEX in $(seq 1 $((${EDPM_TOTAL_NODES} -1))) ; do
cat <<EOF >>kustomization.yaml
    - op: copy
      from: /spec/nodes/edpm-compute-0
      path: /spec/nodes/edpm-compute-${INDEX}
    - op: replace
      path: /spec/nodes/edpm-compute-${INDEX}/ansible/ansibleHost
      value: ${CTLPLANE_IP_ADDRESS_PREFIX}.$((100+${INDEX}))
    - op: replace
      path: /spec/nodes/edpm-compute-${INDEX}/hostName
      value: edpm-compute-${INDEX}
EOF
if [ -n "$BGP" ] && [ "$BGP" = "ovn" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/nodes/edpm-compute-${INDEX}/ansible/ansibleVars
      value:
        edpm_ovn_bgp_agent_local_ovn_peer_ips: ['100.64.$((1+${INDEX})).5', '100.65.$((1+${INDEX})).5']
        edpm_frr_bgp_peers: ['100.64.$((1+${INDEX})).5', '100.65.$((1+${INDEX})).5']
EOF
fi
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/nodes/edpm-compute-${INDEX}/networks
      value:
        - name: CtlPlane
          subnetName: subnet1
          defaultRoute: true
          fixedIP: ${CTLPLANE_IP_ADDRESS_PREFIX}.$((100+${INDEX}))
        - name: InternalApi
          subnetName: subnet1
        - name: Storage
          subnetName: subnet1
        - name: Tenant
          subnetName: subnet1
EOF
if [ -n "$BGP" ]; then
cat <<EOF >>kustomization.yaml
        - name: BgpNet1
          subnetName: subnet$((1+${INDEX}))
          fixedIP: 100.65.$((1+${INDEX})).6
        - name: BgpNet2
          subnetName: subnet$((1+${INDEX}))
          fixedIP: 100.64.$((1+${INDEX})).6
        - name: BgpMainNet
          subnetName: subnet$((1+${INDEX}))
          fixedIP: 172.30.$((1+${INDEX})).2
        - name: BgpMainNet6
          subnetName: subnet$((1+${INDEX}))
          fixedIP: 172.30.$((1+${INDEX})).2
          fixedIP: f00d:f00d:f00d:f00d:f00d:f00d:f00d:00$((1+${INDEX}))2
EOF
fi
    done
fi

# Create a nova-custom service with a reference to nova-extra-config CM
cat <<EOF >>kustomization.yaml
- target:
    kind: OpenStackDataPlaneService
    name: nova
  patch: |-
    - op: replace
      path: /metadata/name
      value: nova-custom
    - op: add
      path: /spec/configMaps
      value:
        - nova-extra-config
EOF

# Create the nova-extra-config CM based on the provided config file
cat <<EOF >>kustomization.yaml
configMapGenerator:
- name: nova-extra-config
  files:
    - 25-nova-extra.conf=${EDPM_EXTRA_NOVA_CONFIG_FILE}
  options:
    disableNameSuffixHash: true
EOF

# Replace the nova service in the nodeset with the new nova-custom service
#
# NOTE(gibi): This is hard to do with kustomize as it only allows
# list item replacemnet by index and not by value, but we cannot
# be sure that the index is not changing in the future by
# adding more services or splitting existing services.
# The kustozmization would be something like:
#     - op: replace
#      path: /spec/services/11
#      value: nova-custom
#
# So we do a replace by value with yq (assuming golang implementation of yq)
yq -i '(.spec.services[] | select(. == "nova")) |= "nova-custom"' *openstackdataplanenodeset*.yaml

kustomization_add_resources

popd
