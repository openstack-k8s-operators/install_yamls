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
    - op: replace
      path: /spec/roles/edpm-compute/preProvisioned
      value: true
    - op: replace
      path: /spec/nodes/edpm-compute-0/ansibleHost
      value: ${EDPM_COMPUTE_IP}
    - op: remove
      path: /spec/nodes/edpm-compute-0/node/ansibleVars
    - op: replace
      path: /spec/nodes/edpm-compute-0/node/networks
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
    - op: add
      path: /spec/roles/edpm-compute/services/0
      value: repo-setup
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
if [ "$EDPM_STORAGE_MGMT_NETWORK" == "true" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/nodes/edpm-compute-0/node/networks/-
      value:
        name: StorageMgmt
        subnetName: subnet1
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/role_networks/-
      value: StorageMgmt
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/networks_lower/StorageMgmt
      value: storage_mgmt
EOF
fi
if oc get pvc ansible-ee-logs -n ${NAMESPACE} 2>&1 1>/dev/null; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/extraMounts
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
if [ "$EDPM_SINGLE_NODE" == "true" ]; then
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
      path: /spec/nodes/edpm-compute-${INDEX}/ansibleHost
      value: 192.168.122.$((100+${INDEX}))
    - op: replace
      path: /spec/nodes/edpm-compute-${INDEX}/hostName
      value: edpm-compute-${INDEX}
    - op: replace
      path: /spec/nodes/edpm-compute-${INDEX}/node/networks/0/fixedIP
      value: 192.168.122.$((100+${INDEX}))
    - op: replace
      path: /spec/nodes/edpm-compute-${INDEX}/node/ansibleSSHPrivateKeySecret
      value: ${EDPM_ANSIBLE_SECRET}
EOF
    done
else
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/nodes/edpm-compute-1/ansibleHost
      value: ${EDPM_COMPUTE_1_IP}
    - op: replace
      path: /spec/nodes/edpm-compute-1/node/networks/0/fixedIP
      value: ${EDPM_COMPUTE_1_IP}
    - op: replace
      path: /spec/nodes/edpm-compute-1/node/ansibleVars
    - op: replace
      path: /spec/nodes/edpm-compute-1/node/ansibleSSHPrivateKeySecret
      value: ${EDPM_ANSIBLE_SECRET}
EOF
fi
if [ ! -z "$EDPM_ANSIBLE_USER" ]; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleUser
      value: ${EDPM_ANSIBLE_USER}
EOF
fi

if [ "$EDPM_CONFIG_NET_ONLY" == "true" ]; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/roles/edpm-compute/services
      value:
        - configure-network
        - validate-network
        - ceph-hci-pre
    - op: remove
      path: /spec/roles/edpm-compute/nodeTemplate/nova
EOF
fi

if [ "$EDPM_HCI_NOVA_CONFIG" == "true" ]; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/nova
      value:
        cellName: cell1
        customServiceConfig: |
          [DEFAULT]
          reserved_host_memory_mb=75000
          [libvirt]
          images_type=rbd
          images_rbd_pool=vms
          images_rbd_ceph_conf=/etc/ceph/ceph.conf
          images_rbd_glance_store_name=default_backend
          images_rbd_glance_copy_poll_interval=15
          images_rbd_glance_copy_timeout=600
          rbd_user=openstack
          rbd_secret_uuid=${EDPM_CEPH_FSID}
        deploy: true
        novaInstance: nova
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/extraMounts
      value:
        - extraVolType: Ceph
          volumes:
          - name: ceph
            secret:
              secretName: ceph-conf-files
          mounts:
          - name: ceph
            mountPath: "/etc/ceph"
            readOnly: true
    - op: replace
      path: /spec/roles/edpm-compute/services
      value:
        - configure-network
        - validate-network
        - ceph-hci-pre
        - install-os
        - ceph-client
        - configure-os
        - run-os
EOF
fi

kustomization_add_resources

popd
