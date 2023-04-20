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
      path: /spec/deployStrategy/deploy
      value: true
    - op: replace
      path: /spec/nodes/edpm-compute-0/ansibleHost
      value: ${EDPM_COMPUTE_IP}
    - op: replace
      path: /spec/nodes/edpm-compute-0/openStackAnsibleEERunnerImage
      value: ${OPENSTACK_RUNNER_IMG}
    - op: replace
      path: /spec/nodes/edpm-compute-0/node/ansibleVars
      value: |
        ctlplane_ip: ${EDPM_COMPUTE_IP}
        internal_api_ip: 172.17.0.100
        storage_ip: 172.18.0.100
        tenant_ip: 172.10.0.100
        fqdn_internal_api: '{{ ansible_fqdn }}'
    - op: replace
      path: /spec/nodes/edpm-compute-0/node/ansibleSSHPrivateKeySecret
      value: ${EDPM_ANSIBLE_SECRET}
    - op: replace
      path: /spec/roles/edpm-compute/openStackAnsibleEERunnerImage
      value: ${OPENSTACK_RUNNER_IMG}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars
      value: |
        service_net_map:
          nova_api_network: internal_api
          nova_libvirt_network: internal_api

        # edpm_network_config
        # Default nic config template for a EDPM compute node
        # These vars are edpm_network_config role vars
        edpm_network_config_template: ${EDPM_NETWORK_CONFIG_TEMPLATE}
        edpm_network_config_hide_sensitive_logs: false
        #
        # These vars are for the network config templates themselves and are
        # considered EDPM network defaults.
        neutron_physical_bridge_name: br-ex
        neutron_public_interface_name: eth0
        ctlplane_mtu: 1500
        ctlplane_subnet_cidr: 24
        ctlplane_gateway_ip: 192.168.122.1
        ctlplane_host_routes:
        - ip_netmask: 0.0.0.0/0
          next_hop: 192.168.122.1
        external_mtu: 1500
        external_vlan_id: 44
        external_cidr: '24'
        external_host_routes: []
        internal_api_mtu: 1500
        internal_api_vlan_id: 20
        internal_api_cidr: '24'
        internal_api_host_routes: []
        storage_mtu: 1500
        storage_vlan_id: 21
        storage_cidr: '24'
        storage_host_routes: []
        tenant_mtu: 1500
        tenant_vlan_id: 22
        tenant_cidr: '24'
        tenant_host_routes: []
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

        edpm_ovn_metadata_agent_DEFAULT_transport_url: ${EDPM_OVN_METADATA_AGENT_TRANSPORT_URL}
        edpm_ovn_metadata_agent_metadata_agent_ovn_ovn_sb_connection: ${EDPM_OVN_METADATA_AGENT_SB_CONNECTION}
        edpm_ovn_metadata_agent_metadata_agent_DEFAULT_nova_metadata_host: ${EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST}
        edpm_ovn_metadata_agent_metadata_agent_DEFAULT_metadata_proxy_shared_secret: ${EDPM_OVN_METADATA_AGENT_PROXY_SHARED_SECRET}
        edpm_ovn_metadata_agent_DEFAULT_bind_host: ${EDPM_OVN_METADATA_AGENT_BIND_HOST}
        edpm_chrony_ntp_servers:
        - ${EDPM_CHRONY_NTP_SERVER}

        ctlplane_dns_nameservers:
        - ${EDPM_DNS_SERVER}
        dns_search_domains: []
        edpm_ovn_dbs:
        - ${EDPM_OVN_DBS}

        registry_name: quay.io
        registry_namespace: tripleozedcentos9
        image_tag: current-tripleo
        edpm_ovn_controller_agent_image: "{{ registry_name }}/{{ registry_namespace }}/openstack-ovn-controller:{{ image_tag }}"
        edpm_iscsid_image: "{{ registry_name }}/{{ registry_namespace }}/openstack-iscsid:{{ image_tag }}"
        edpm_logrotate_crond_image: "{{ registry_name }}/{{ registry_namespace }}/openstack-cron:{{ image_tag }}"
        edpm_nova_compute_container_image: "{{ registry_name }}/{{ registry_namespace }}/openstack-nova-compute:{{ image_tag }}"
        edpm_nova_libvirt_container_image: "{{ registry_name }}/{{ registry_namespace }}/openstack-nova-libvirt:{{ image_tag }}"
        edpm_ovn_metadata_agent_image: "{{ registry_name }}/{{ registry_namespace }}/openstack-neutron-metadata-agent-ovn:{{ image_tag }}"

        gather_facts: false
        enable_debug: false
        # edpm firewall, change the allowed CIDR if needed
        edpm_sshd_configure_firewall: true
        edpm_sshd_allowed_ranges: ${EDPM_SSHD_ALLOWED_RANGES}
        # SELinux module
        edpm_selinux_mode: enforcing
        edpm_hosts_entries_undercloud_hosts_entries: []
        # edpm_hosts_entries role
        edpm_hosts_entries_extra_hosts_entries:
        - 172.17.0.80 glance-internal.openstack.svc neutron-internal.openstack.svc cinder-internal.openstack.svc nova-internal.openstack.svc placement-internal.openstack.svc keystone-internal.openstack.svc
        - 172.17.0.85 rabbitmq.openstack.svc
        - 172.17.0.86 rabbitmq-cell1.openstack.svc
        edpm_hosts_entries_vip_hosts_entries: []
        hosts_entries: []
        hosts_entry: []
        plan: overcloud
    - op: replace
      path: /spec/roles/edpm-compute/networkAttachments
      value: ${EDPM_NADS}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleSSHPrivateKeySecret
      value: ${EDPM_ANSIBLE_SECRET}
EOF
if [ "$EDPM_SINGLE_NODE" == "true" ]; then
cat <<EOF >>kustomization.yaml
    - op: remove
      path: /spec/nodes/edpm-compute-1
EOF
else
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/nodes/edpm-compute-1/ansibleHost
      value: ${EDPM_COMPUTE_1_IP}
    - op: replace
      path: /spec/nodes/edpm-compute-1/openStackAnsibleEERunnerImage
      value: ${OPENSTACK_RUNNER_IMG}
    - op: replace
      path: /spec/nodes/edpm-compute-1/node/ansibleVars
      value: |
        ctlplane_ip: ${EDPM_COMPUTE_1_IP}
        internal_api_ip: 172.17.0.101
        storage_ip: 172.18.0.101
        tenant_ip: 172.10.0.101
        fqdn_internal_api: '{{ ansible_fqdn }}'
    - op: replace
      path: /spec/nodes/edpm-compute-1/node/ansibleSSHPrivateKeySecret
      value: ${EDPM_ANSIBLE_SECRET}
EOF
fi

kustomization_add_resources

popd
