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
NETWORK_IPADDRESS=${BMAAS_NETWORK_IPADDRESS:-172.22.0.3}
DATAPLANE_CR_URL=${DATAPLANE_CR_URL:-https://raw.githubusercontent.com/openstack-k8s-operators/dataplane-operator/main/config/samples/dataplane_v1beta1_openstackdataplane_baremetal.yaml}
DATAPLANE_CR_FILE=${DATAPLANE_CR_FILE:-dataplane.yaml}
NETCONFIG_CR_URL=${NETCONFIG_CR_URL:-https://raw.githubusercontent.com/openstack-k8s-operators/infra-operator/main/config/samples/network_v1beta1_netconfig.yaml}
NETCONFIG_CR_FILE=${NETCONFIG_CR_FILE:-netconfig.yaml}
DNSMASQ_CR_URL=${DNSMASQ_CR_URL:-https://raw.githubusercontent.com/openstack-k8s-operators/infra-operator/main/config/samples/network_v1beta1_dnsmasq.yaml}
DNSMASQ_CR_FILE=${DNSMASQ_CR_FILE:-dnsmasq.yaml}
BMH_CR_FILE=${BMH_CR_FILE:-bmh_deploy.yaml}

pushd ${DEPLOY_DIR}

curl -L -k ${DATAPLANE_CR_URL} -o ${DATAPLANE_CR_FILE}
curl -L -k ${NETCONFIG_CR_URL} -o ${NETCONFIG_CR_FILE}
curl -L -k ${DNSMASQ_CR_URL} -o ${DNSMASQ_CR_FILE}

cat <<EOF >>kustomization.yaml

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ${DATAPLANE_CR_FILE}
  - ${NETCONFIG_CR_FILE}
  - ${DNSMASQ_CR_FILE}
  - ${BMH_CR_FILE}
namespace: ${NAMESPACE}
patches:
- target:
    kind: DNSMasq
  patch: |-
    - op: replace
      path: /spec/externalEndpoints/0/loadBalancerIPs/0
      value: 172.22.0.80
    - op: replace
      path: /spec/options/0/values/0/
      value: ${NETWORK_IPADDRESS}
patches:
- target:
    kind: NetConfig
  patch: |-
    - op: replace
      path: /spec/networks/0/subnets/0/cidr
      value: 172.22.0.0/24
    - op: replace
      path: /spec/networks/0/subnets/0/gateway
      value: ${NETWORK_IPADDRESS}
    - op: replace
      path: /spec/networks/0/subnets/0/allocationRanges/0/start
      value: 172.22.0.100
    - op: replace
      path: /spec/networks/0/subnets/0/allocationRanges/0/end
      value: 172.22.0.130
    - op: replace
      path: /spec/networks/0/subnets/0/allocationRanges/1/start
      value: 172.22.0.150
    - op: replace
      path: /spec/networks/0/subnets/0/allocationRanges/1/end
      value: 172.22.0.200
patches:
- target:
    kind: OpenStackDataPlane
  patch: |-
    - op: replace
      path: /spec/nodes/edpm-compute-0/ansibleHost
      value: 172.22.0.100
    - op: replace
      path: /spec/nodes/edpm-compute-0/node/ansibleVars
      value: |
          ctlplane_ip: 172.22.0.100
          internal_api_ip: 172.17.0.100
          storage_ip: 172.18.0.100
          tenant_ip: 172.19.0.100
          fqdn_internal_api: edpm-compute-0.example.com

$(if [[ $NODE_COUNT -eq 2 ]]; then
cat <<SECOND_NODE_EOF
    - op: replace
      path: /spec/nodes/edpm-compute-0/ansibleHost
      value: 172.22.0.101
    - op: replace
      path: /spec/nodes/edpm-compute-1/node/ansibleVars
      value: |
          ctlplane_ip: 172.22.0.101
          internal_api_ip: 172.17.0.101
          storage_ip: 172.18.0.101
          tenant_ip: 172.19.0.101
          fqdn_internal_api: edpm-compute-1.example.com
SECOND_NODE_EOF
else
cat <<SECOND_NODE_EOF
    - op: remove
      path: /spec/nodes/edpm-compute-1
SECOND_NODE_EOF
fi)
    - op: replace
      path: /spec/roles/edpm-compute/baremetalSetTemplate/ctlplaneGateway
      value: ${NETWORK_IPADDRESS}
    - op: replace
      path: /spec/roles/edpm-compute/baremetalSetTemplate/bootstrapDns
      value:
        - ${NETWORK_IPADDRESS}
    - op: replace
      path: /spec/roles/edpm-compute/baremetalSetTemplate/bmhNamespace
      value: ${NAMESPACE}
    - op: replace
      path: /spec/roles/edpm-compute/baremetalSetTemplate/ctlplaneInterface
      value: enp1s0
    - op: add
      path: /spec/roles/edpm-compute/baremetalSetTemplate/provisioningInterface
      value: ${PROVISIONING_INTERFACE}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars
      value: |
          service_net_map:
            nova_api_network: internal_api
            nova_libvirt_network: internal_api
          edpm_chrony_ntp_servers:
            - 0.pool.ntp.org
            - 1.pool.ntp.org
          growvols_args: '/var=100%'
          # edpm_network_config
          # Default nic config template for a EDPM compute node
          # These vars are edpm_network_config role vars
          edpm_network_config_template: templates/single_nic_vlans/single_nic_vlans.j2
          edpm_network_config_hide_sensitive_logs: false
          neutron_physical_bridge_name: br-ex
          neutron_public_interface_name: eth0
          ctlplane_mtu: 1500
          ctlplane_subnet_cidr: 24
          ctlplane_gateway_ip: ${NETWORK_IPADDRESS}
          ctlplane_host_routes:
          - ip_netmask: 0.0.0.0/0
            next_hop: ${NETWORK_IPADDRESS}
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

          edpm_ovn_metadata_agent_DEFAULT_transport_url: rabbit://default_user@rabbitmq.openstack.svc:5672
          edpm_ovn_metadata_agent_metadata_agent_ovn_ovn_sb_connection: tcp:10.217.5.121:6642
          edpm_ovn_metadata_agent_metadata_agent_DEFAULT_nova_metadata_host: 127.0.0.1
          edpm_ovn_metadata_agent_metadata_agent_DEFAULT_metadata_proxy_shared_secret: 12345678
          edpm_ovn_metadata_agent_DEFAULT_bind_host: 127.0.0.1
          ctlplane_dns_nameservers:
          - 172.22.0.3
          dns_search_domains: []
          edpm_ovn_dbs:
          - 172.22.0.3
          edpm_ovn_controller_agent_image: quay.io/podified-antelope-centos9/openstack-ovn-controller:current-podified
          edpm_iscsid_image: quay.io/podified-antelope-centos9/openstack-iscsid:current-podified
          edpm_logrotate_crond_image: quay.io/podified-antelope-centos9/openstack-cron:current-podified
          edpm_nova_compute_container_image: quay.io/podified-antelope-centos9/openstack-nova-compute:current-podified
          edpm_nova_libvirt_container_image: quay.io/podified-antelope-centos9/openstack-nova-libvirt:current-podified
          edpm_ovn_metadata_agent_image: quay.io/podified-antelope-centos9/openstack-neutron-metadata-agent-ovn:current-podified

          gather_facts: false
          enable_debug: false
          # edpm firewall, change the allowed CIDR if needed
          edpm_sshd_configure_firewall: true
          edpm_sshd_allowed_ranges: ['172.22.0.0/24']
          # SELinux module
          edpm_selinux_mode: enforcing
          edpm_hosts_entries_undercloud_hosts_entries: []
          # edpm_hosts_entries role
          edpm_hosts_entries_extra_hosts_entries:
          - 172.17.0.80 glance-internal.openstack.svc neutron-internal.openstack.svc cinder-internal.openstack.svc nova-internal.openstack.svc placement-internal.openstack.svc keystone-internal.openstack.svc
          - 172.17.0.85 rabbitmq.openstack.svc
          - 172.17.0.86 rabbitmq-cell1.openstack.svc
          edpm_hosts_entries_vip_hosts_entries: []
EOF
popd
