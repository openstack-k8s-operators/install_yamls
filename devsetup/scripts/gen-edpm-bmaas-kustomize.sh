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
OPENSTACK_DATAPLANE=${OPENSTACK_DATAPLANE:-config/samples/dataplane_v1beta1_openstackdataplane_baremetal_with_ipam.yaml}
DATAPLANE_REPO=${DATAPLANE_REPO:-https://github.com/openstack-k8s-operators/dataplane-operator.git}
DATAPLNE_BRANCH=${DATAPLANE_BRANCH:-main}
DATAPLANE_CR_FILE=${DATAPLANE_CR_FILE:-dataplane.yaml}

mkdir -p ${OPERATOR_DIR} ${DEPLOY_DIR}

# Add DataPlane CR to the DEPLOY_DIR
rm -Rf ${OPERATOR_DIR}/dataplane-operator || true
pushd ${OPERATOR_DIR} && git clone $(if [ ${DATAPLANE_BRANCH} ]; then echo -b ${DATAPLANE_BRANCH}; fi) \
    ${DATAPLANE_REPO} "dataplane-operator" && popd
cp  ${OPERATOR_DIR}/dataplane-operator/${OPENSTACK_DATAPLANE} ${DEPLOY_DIR}/${DATAPLANE_CR_FILE}

pushd ${DEPLOY_DIR}

cat <<EOF >>kustomization.yaml

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ${DATAPLANE_CR_FILE}
  - ${BMH_CR_FILE}
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
      path: /spec/roles/edpm-compute/baremetalSetTemplate/dnsSearchDomains/0
      value: ctlplane.example.com
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleSSHPrivateKeySecret
      value: dataplane-ansible-ssh-private-key-secret
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/nova
      value: {}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_dbs
      value: [${NETWORK_IPADDRESS}]
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_controller_agent_image
      value: "${REGISTRY_URL}/openstack-ovn-controller:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_iscsid_image
      value: "${REGISTRY_URL}/openstack-iscsid:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_logrotate_crond_image
      value: "${REGISTRY_URL}/openstack-cron:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_nova_compute_container_image
      value: "${REGISTRY_URL}/openstack-nova-compute:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_nova_libvirt_container_image
      value: "${REGISTRY_URL}/openstack-nova-libvirt:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_image
      value: "${REGISTRY_URL}/openstack-neutron-metadata-agent-ovn:${CONTAINER_TAG}"
EOF
popd
