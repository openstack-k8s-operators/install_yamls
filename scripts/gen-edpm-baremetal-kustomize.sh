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

if [ -z "$EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST" ]; then
    echo "Please set EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST"; exit 1
fi

if [ -z "$EDPM_OVN_METADATA_AGENT_TRANSPORT_URL" ]; then
    echo "Please set EDPM_OVN_METADATA_AGENT_TRANSPORT_URL"; exit 1
fi

if [ -z "$EDPM_OVN_METADATA_AGENT_SB_CONNECTION" ]; then
    echo "Please set EDPM_OVN_METADATA_AGENT_SB_CONNECTION"; exit 1
fi

if [ -z "$EDPM_OVN_DBS" ]; then
    echo "Please set EDPM_OVN_DBS"; exit 1
fi

if [ -z "$EDPM_BMH_NAMESPACE" ]; then
    echo "Please set EDPM_BMH_NAMESPACE"; exit 1
fi

# This statement is first since we don't want to start creating CR if provided file is not correct
if [ ! -z "$EDPM_BAREMETAL_NETWORK_CONFIG_OVERRIDE" ]; then
    if [ ! -f "$EDPM_BAREMETAL_NETWORK_CONFIG_OVERRIDE" ]; then
        echo "Please esnure file ${EDPM_BAREMETAL_NETWORK_CONFIG_OVERRIDE} exists"
        exit 1
    fi
    NETWORK_CONFIG_JSON=$(cat "${EDPM_BAREMETAL_NETWORK_CONFIG_OVERRIDE}" | jq -c -r . 2>/dev/null)
    if [ ! "$NETWORK_CONFIG_JSON" ]; then
        echo "Please esnure file ${EDPM_BAREMETAL_NETWORK_CONFIG_OVERRIDE} contains a valid JSON"
        exit 1
    fi
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
      path: /spec/deployStrategy/deploy
      value: true
    - op: add
      path: /spec/roles/edpm-compute/baremetalSetTemplate/bmhNamespace
      value: ${EDPM_BMH_NAMESPACE}
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/networks
      value:
        - name: CtlPlane
          subnetName: subnet1
          defaultRoute: true
        - name: InternalApi
          subnetName: subnet1
        - name: Storage
          subnetName: subnet1
        - name: Tenant
          subnetName: subnet1
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_DEFAULT_transport_url
      value: ${EDPM_OVN_METADATA_AGENT_TRANSPORT_URL}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_metadata_agent_ovn_ovn_sb_connection
      value: ${EDPM_OVN_METADATA_AGENT_SB_CONNECTION}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_metadata_agent_DEFAULT_nova_metadata_host
      value: ${EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_metadata_agent_DEFAULT_metadata_proxy_shared_secret
      value: ${EDPM_OVN_METADATA_AGENT_PROXY_SHARED_SECRET}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_DEFAULT_bind_host
      value: ${EDPM_OVN_METADATA_AGENT_BIND_HOST}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_chrony_ntp_servers
      value:
        - ${EDPM_CHRONY_NTP_SERVER}
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/networkConfig
      value:
       template: ${EDPM_NETWORK_CONFIG_TEMPLATE}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_dbs
      value: ${EDPM_OVN_DBS}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/registry_url
      value: ${EDPM_REGISTRY_URL}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/image_tag
      value: ${EDPM_CONTAINER_TAG}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_sshd_allowed_ranges
      value: ${EDPM_SSHD_ALLOWED_RANGES}
    - op: add
      path: /spec/roles/edpm-compute/env/0
      value: {"name": "ANSIBLE_CALLBACKS_ENABLED", "value": "profile_tasks"}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleSSHPrivateKeySecret
      value: ${EDPM_ANSIBLE_SECRET}
EOF
if [ "$EDPM_ROOT_PASSWORD_SECRET" != "" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/roles/edpm-compute/baremetalSetTemplate/passwordSecret
      value:
        name: ${EDPM_ROOT_PASSWORD_SECRET}
        namespace: ${NAMESPACE}
EOF
fi
if [ "$EDPM_PROVISIONING_INTERFACE" != "" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/roles/edpm-compute/baremetalSetTemplate/provisioningInterface
      value: ${EDPM_PROVISIONING_INTERFACE}
EOF
fi
if [ "$EDPM_CTLPLANE_INTERFACE" != "" ]; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/roles/edpm-compute/baremetalSetTemplate/ctlplaneInterface
      value: ${EDPM_CTLPLANE_INTERFACE}
EOF
fi
if [ "$EDPM_TOTAL_NODES" -eq 1 ]; then
cat <<EOF >>kustomization.yaml
    - op: remove
      path: /spec/nodes/edpm-compute-1
EOF
elif [ "$EDPM_TOTAL_NODES" -gt 2 ]; then
    for INDEX in $(seq 1 $((${EDPM_TOTAL_NODES} -1))) ; do
cat <<EOF >>kustomization.yaml
    - op: copy
      from: /spec/nodes/edpm-compute-0
      path: /spec/nodes/edpm-compute-${INDEX}
    - op: replace
      path: /spec/nodes/edpm-compute-${INDEX}/hostName
      value: edpm-compute-${INDEX}
EOF
    done
fi
if [ ! -z "$EDPM_ANSIBLE_USER" ]; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleUser
      value: ${EDPM_ANSIBLE_USER}
EOF
fi

# Used for edpm_kernel role to provide additional kernel arguments
if [ ! -z "$EDPM_BAREMETAL_KERNEL_ARGS" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_kernel_args
      value: ${EDPM_BAREMETAL_KERNEL_ARGS}
EOF
fi

# Used for edpm_kernel role to configure huge pages
if [ ! -z "$EDPM_BAREMETAL_KERNEL_HUGEPAGES" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_kernel_hugepages
      value: ${EDPM_BAREMETAL_KERNEL_HUGEPAGES}
EOF
fi

# Used for edpm_tuned role to configure tuned profile
if [ ! -z "$EDPM_BAREMETAL_TUNED_PROFILE" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_tuned_profile
      value: ${EDPM_BAREMETAL_TUNED_PROFILE}
EOF
fi

# Used for edpm_tuned role to configure tuned profile
if [ ! -z "$EDPM_BAREMETAL_TUNED_ISOLATED_CORES" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_tuned_isolated_cores
      value: ${EDPM_BAREMETAL_TUNED_ISOLATED_CORES}
EOF
fi

# Used for edpm_network_config role to provide custom YAML file for network configuration
if [ ! -z "$NETWORK_CONFIG_JSON" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_network_config_override
      value: '${NETWORK_CONFIG_JSON}'
EOF
fi

kustomization_add_resources

popd
