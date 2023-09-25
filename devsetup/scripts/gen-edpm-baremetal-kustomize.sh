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
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
NODE_COUNT=${NODE_COUNT:-1}
BMH_CR_FILE=${BMH_CR_FILE:-bmh_deploy.yaml}
OPERATOR_DIR=${OPERATOR_DIR:-../out/operator}
DATAPLANE_REPO=${DATAPLANE_REPO:-https://github.com/openstack-k8s-operators/dataplane-operator.git}
DATAPLANE_BRANCH=${DATAPLANE_BRANCH:-main}
OPENSTACK_DATAPLANENODESET_BAREMETAL=${OPENSTACK_DATAPLANENODESET_BAREMETAL:-config/samples/dataplane_v1beta1_openstackdataplanenodeset_baremetal_with_ipam.yaml}
OPENSTACK_DATAPLANEDEPLOYMENT_BAREMETAL=${OPENSTACK_DATAPLANEDEPLOYMENT_BAREMETAL:-config/samples/dataplane_v1beta1_openstackdataplanedeployment_baremetal_with_ipam.yaml}
DATAPLANE_NODESET_BAREMETAL_CR=${OPERATOR_DIR}/dataplane-operator/${OPENSTACK_DATAPLANENODESET_BAREMETAL}
DATAPLANE_DEPLOYMENT_BAREMETAL_CR=${OPERATOR_DIR}/dataplane-operator/${OPENSTACK_DATAPLANEDEPLOYMENT_BAREMETAL}
DATAPLANE_NODESET_CR_FILE=${DATAPLANE_NODESET_CR_FILE:-dataplanenodeset.yaml}
DATAPLANE_DEPLOYMENT_CR_FILE=${DATAPLANE_DEPLOYMENT_CR_FILE:-dataplanedeployment.yaml}
GIT_CLONE_OPTS=${GIT_CLONE_OPTS:-}

mkdir -p ${OPERATOR_DIR} ${DEPLOY_DIR}

rm -Rf ${OPERATOR_DIR}/dataplane-operator || true
pushd ${OPERATOR_DIR} && git clone ${GIT_CLONE_OPTS} $(if [ ${DATAPLANE_BRANCH} ]; then echo -b ${DATAPLANE_BRANCH}; fi) \
    ${DATAPLANE_REPO} "dataplane-operator" && popd
cp ${SCRIPTPATH}/../edpm/services/* ${OPERATOR_DIR}/dataplane-operator/config/services
NAMESPACE=${NAMESPACE} DEPLOY_DIR=${OPERATOR_DIR}/dataplane-operator/config/services KIND=OpenStackDataPlaneService bash ${SCRIPTPATH}/../../scripts/gen-edpm-services-kustomize.sh
oc kustomize ${OPERATOR_DIR}/dataplane-operator/config/services | oc apply -f -
oc apply -f ${SCRIPTPATH}/../edpm/config/ansible-ee-env.yaml
cp  ${OPERATOR_DIR}/dataplane-operator/${OPENSTACK_DATAPLANENODESET_BAREMETAL} ${DEPLOY_DIR}/${DATAPLANE_NODESET_CR_FILE}
cp  ${OPERATOR_DIR}/dataplane-operator/${OPENSTACK_DATAPLANEDEPLOYMENT_BAREMETAL} ${DEPLOY_DIR}/${DATAPLANE_DEPLOYMENT_CR_FILE}

pushd ${DEPLOY_DIR}

cat <<EOF >>kustomization.yaml

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ${BMH_CR_FILE}
  - ${DATAPLANE_NODESET_CR_FILE}
  - ${DATAPLANE_DEPLOYMENT_CR_FILE}
namespace: ${NAMESPACE}
patches:
- target:
    kind: OpenStackDataPlaneNodeSet
  patch: |-
    - op: add
      path: /spec/services/0
      value: repo-setup
    - op: replace
      path: /spec/baremetalSetTemplate/bmhNamespace
      value: ${NAMESPACE}
    - op: replace
      path: /spec/baremetalSetTemplate/ctlplaneInterface
      value: enp1s0
    - op: add
      path: /spec/baremetalSetTemplate/provisioningInterface
      value: ${PROVISIONING_INTERFACE}
    - op: add
      path: /spec/env/0
      value: {"name": "ANSIBLE_CALLBACKS_ENABLED", "value": "profile_tasks"}
    - op: add
      path: /spec/nodeTemplate/ansibleSSHPrivateKeySecret
      value: dataplane-ansible-ssh-private-key-secret
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/edpm_chrony_ntp_servers
      value:
        - ${EDPM_CHRONY_NTP_SERVER}
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/registry_url
      value: ${REGISTRY_URL}
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/image_tag
      value: ${CONTAINER_TAG}
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/edpm_sshd_allowed_ranges
      value: ${EDPM_SSHD_ALLOWED_RANGES}
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleVars/growvols_args
      value: '/=8GB /tmp=1GB /home=1GB /var=80%'
    - op: replace
      path: /spec/nodeTemplate/ansible/ansibleUser
      value: ${EDPM_ANSIBLE_USER:-"cloud-admin"}
    - op: replace
      path: /spec/baremetalSetTemplate/cloudUserName
      value: ${EDPM_ANSIBLE_USER:-"cloud-admin"}

EOF

if [ "$NODE_COUNT" -gt 1 ]; then
    for INDEX in $(seq 1 $((${NODE_COUNT} -1))) ; do
 cat <<EOF >> kustomization.yaml
    - op: copy
      from: /spec/nodes/edpm-compute-0
      path: /spec/nodes/edpm-compute-${INDEX}
    - op: replace
      path: /spec/nodes/edpm-compute-${INDEX}/hostName
      value: edpm-compute-${INDEX}
EOF
    done
fi

if [ "$EDPM_ROOT_PASSWORD_SECRET" != "" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/baremetalSetTemplate/passwordSecret
      value:
        name: ${EDPM_ROOT_PASSWORD_SECRET}
        namespace: ${NAMESPACE}
EOF
fi

popd
