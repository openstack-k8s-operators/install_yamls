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

# Patch netconfig to add default route
oc patch netconfig -n ${NAMESPACE} netconfig --type json \
    -p="[{"op": "add", "path": "/spec/networks/0/subnets/0/routes", \
    "value": [{"destination": "0.0.0.0/0", "nexthop": ${NETWORK_IPADDRESS}}]}]"

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
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars
      value: |
          growvols_args: '/=8GB /tmp=1GB /home=1GB /var=80%'
          service_net_map:
            nova_api_network: internal_api
            nova_libvirt_network: internal_api
          edpm_chrony_ntp_servers:
            - 0.pool.ntp.org
            - 1.pool.ntp.org
          # edpm_network_config
          # Default nic config template for a EDPM compute node
          # These vars are edpm_network_config role vars
          edpm_network_config_template: templates/single_nic_vlans/single_nic_vlans.j2
          edpm_network_config_hide_sensitive_logs: false
          neutron_physical_bridge_name: br-ex
          neutron_public_interface_name: eth0
          role_networks:
          - InternalApi
          - Storage
          - Tenant
          networks_lower:
            External: external
            InternalApi: internal_api
            Storage: storage
            Tenant: tenant

          # edpm_nodes_validation
          edpm_nodes_validation_validate_controllers_icmp: false
          edpm_nodes_validation_validate_gateway_icmp: false

          edpm_ovn_metadata_agent_DEFAULT_transport_url: rabbit://default_user@rabbitmq.openstack.svc:5672
          edpm_ovn_metadata_agent_metadata_agent_ovn_ovn_sb_connection: tcp:10.217.5.121:6642
          edpm_ovn_metadata_agent_metadata_agent_DEFAULT_nova_metadata_host: 127.0.0.1
          edpm_ovn_metadata_agent_metadata_agent_DEFAULT_metadata_proxy_shared_secret: 12345678
          edpm_ovn_metadata_agent_DEFAULT_bind_host: 127.0.0.1
          dns_search_domains: []
          edpm_ovn_dbs:
          - ${NETWORK_IPADDRESS}
          registry_url: ${REGISTRY_URL}
          image_tag: ${CONTAINER_TAG}
          edpm_ovn_controller_agent_image: "{{ registry_url }}/openstack-ovn-controller:{{ image_tag }}"
          edpm_iscsid_image: "{{ registry_url }}/openstack-iscsid:{{ image_tag }}"
          edpm_logrotate_crond_image: "{{ registry_url }}/openstack-cron:{{ image_tag }}"
          edpm_nova_compute_container_image: "{{ registry_url }}/openstack-nova-compute:{{ image_tag }}"
          edpm_nova_libvirt_container_image: "{{ registry_url }}/openstack-nova-libvirt:{{ image_tag }}"
          edpm_ovn_metadata_agent_image: "{{ registry_url }}/openstack-neutron-metadata-agent-ovn:{{ image_tag }}"

          gather_facts: false
          enable_debug: false
          # edpm firewall, change the allowed CIDR if needed
          edpm_sshd_configure_firewall: true
          edpm_sshd_allowed_ranges: ['192.168.122.0/24']
          # SELinux module
          edpm_selinux_mode: enforcing

          # Remove these after edpm.edpm_hosts_entries role has been dropped
          edpm_hosts_entries_undercloud_hosts_entries: []
          edpm_hosts_entries_extra_hosts_entries: []
          edpm_hosts_entries_vip_hosts_entries: []


EOF
popd
