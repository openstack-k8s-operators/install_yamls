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

NAMESPACE=${NAMESPACE:-"openstack"}
DEPLOY_DIR=${DEPLOY_DIR:-"../out/edpm"}
NODE_COUNT=${NODE_COUNT:-2}
NETWORK_IPADDRESS=${BMAAS_NETWORK_IPADDRESS:-192.168.122.1}
BMH_CR_FILE=${BMH_CR_FILE:-bmh_deploy.yaml}
OPERATOR_DIR=${OPERATOR_DIR:-../out/operator}
DATAPLANE_REPO=${DATAPLANE_REPO:-https://github.com/openstack-k8s-operators/dataplane-operator.git}
DATAPLNE_BRANCH=${DATAPLANE_BRANCH:-main}
OPENSTACK_DATAPLANE_BAREMETAL=${OPENSTACK_DATAPLANE_BAREMETAL:-config/samples/dataplane_v1beta1_openstackdataplane_baremetal_with_ipam.yaml}
DATAPLANE_BAREMETAL_CR=${OPERATOR_DIR}/dataplane-operator/${OPENSTACK_DATAPLANE_BAREMETAL}
DATAPLANE_CR_FILE=${DATAPLANE_CR_FILE:-dataplane.yaml}
GIT_CLONE_OPTS=${GIT_CLONE_OPTS:-}

mkdir -p ${OPERATOR_DIR} ${DEPLOY_DIR}

rm -Rf ${OPERATOR_DIR}/dataplane-operator || true
pushd ${OPERATOR_DIR} && git clone ${GIT_CLONE_OPTS} $(if [ ${DATAPLANE_BRANCH} ]; then echo -b ${DATAPLANE_BRANCH}; fi) \
    ${DATAPLANE_REPO} "dataplane-operator" && popd
cp  ${OPERATOR_DIR}/dataplane-operator/${OPENSTACK_DATAPLANE_BAREMETAL} ${DEPLOY_DIR}/${DATAPLANE_CR_FILE}

pushd ${DEPLOY_DIR}

cat <<EOF >>kustomization.yaml

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ${BMH_CR_FILE}
  - ${DATAPLANE_CR_FILE}
namespace: ${NAMESPACE}
patches:
- target:
    kind: OpenStackDataPlane
  patch: |-
$(if [[ $NODE_COUNT -eq 1 ]]; then
cat <<SECOND_NODE_EOF
    - op: remove
      path: /spec/nodes/edpm-compute-1
SECOND_NODE_EOF
fi)
    - op: replace
      path: /spec/roles/edpm-compute/baremetalSetTemplate/bmhNamespace
      value: ${NAMESPACE}
    - op: replace
      path: /spec/roles/edpm-compute/baremetalSetTemplate/ctlplaneInterface
      value: enp1s0
    - op: add
      path: /spec/roles/edpm-compute/baremetalSetTemplate/provisioningInterface
      value: ${PROVISIONING_INTERFACE}
    - op: add
      path: /spec/roles/edpm-compute/env/0
      value: {"name": "ANSIBLE_CALLBACKS_ENABLED", "value": "profile_tasks"}
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleSSHPrivateKeySecret
      value: dataplane-ansible-ssh-private-key-secret
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
      value: ${NETWORK_IPADDRESS}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/registry_url
      value: ${REGISTRY_URL}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/image_tag
      value: ${CONTAINER_TAG}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_sshd_allowed_ranges
      value: ${EDPM_SSHD_ALLOWED_RANGES}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/growvols_args
      value: '/=8GB /tmp=1GB /home=1GB /var=80%'

EOF
popd
