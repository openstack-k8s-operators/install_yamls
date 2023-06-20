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
RHEL_IMAGE_URL=${RHEL_IMAGE_URL:-"https://images.rdoproject.org/centos9/master/rdo_trunk/current-tripleo/overcloud-hardened-uefi-full.qcow2"}
NETWORK_NAME=${NETWORK_NAME:-"crc-bmaas"}
NODE_NAME_PREFIX=${NODE_NAME_PREFIX:-"crc-bmaas"}
OPERATOR_DIR=${OPERATOR_DIR:-../out/operator}
OUTPUT_DIR=${OUTPUT_DIR:-"../out/edpm"}
NODE_COUNT=${BMAAS_NODE_COUNT:-2}
NETWORK_IPADDRESS=${BMAAS_NETWORK_IPADDRESS:-172.22.0.3}
NODE_INDEX=0
while IFS= read -r instance; do
    export uuid_${NODE_INDEX}="${instance% *}"
    name="${instance#* }"
    export mac_address_${NODE_INDEX}=$(virsh --connect=qemu:///system domiflist "$name" | grep "${NETWORK_NAME}" | awk '{print $5}')
    echo ${mac_address_0}
    NODE_INDEX=$((NODE_INDEX+1))
done <<< "$(virsh --connect=qemu:///system list --all --uuid --name | grep "${NODE_NAME_PREFIX}")"

mkdir -p ${OUTPUT_DIR}

for (( i=0; i<${NODE_COUNT}; i++ )); do
    mac_var=mac_address_${i}
    uuid_var=uuid_${i}
    cat <<EOF >>${OUTPUT_DIR}/bmh_deploy.yaml
---
# This is the secret with the BMC credentials (Redfish in this case).
apiVersion: v1
kind: Secret
metadata:
  name: node-${i}-bmc-secret
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: crc-bmaas-${i}
  annotations:
    inspect.metal3.io: disabled
spec:
  bmc:
    address: redfish+http://sushy-emulator.apps-crc.testing/redfish/v1/Systems/${!uuid_var}
    credentialsName: node-${i}-bmc-secret
  bootMACAddress: ${!mac_var}
  bootMode: UEFI
  online: false
  rootDeviceHints:
    deviceName: /dev/vda
EOF
done

# Create the dataplane services

DATAPLANE_REPO=${DATAPLANE_REPO:-https://github.com/openstack-k8s-operators/dataplane-operator.git}
DATAPLNE_BRANCH=${DATAPLANE_BRANCH:-main}

mkdir -p ${OPERATOR_DIR}
rm -Rf ${OPERATOR_DIR}/dataplane-operator || true
pushd ${OPERATOR_DIR} && git clone $(if [ ${DATAPLANE_BRANCH} ]; then echo -b ${DATAPLANE_BRANCH}; fi) \
    ${DATAPLANE_REPO} "dataplane-operator" && popd
oc apply -f ${OPERATOR_DIR}/dataplane-operator/config/services

# Create the default NetConfig from samples
INFRA_REPO=${INFRA_REPO:-https://github.com/openstack-k8s-operators/infra-operator.git}
INFRA_BRANCH=${INFRA_BRANCH:-main}

rm -Rf ${OPERATOR_DIR}/infra-operator || true
pushd ${OPERATOR_DIR} && git clone  $(if [ ${INFRA_BRANCH} ]; then echo -b ${INFRA_BRANCH}; fi) \
    ${INFRA_REPO} "infra-operator" && popd
oc apply -f ${OPERATOR_DIR}/infra-operator/config/samples/network_v1beta1_netconfig.yaml


cat <<EOF >${OUTPUT_DIR}/dataplane.yaml
---
apiVersion: dataplane.openstack.org/v1beta1
kind: OpenStackDataPlane
metadata:
  name: openstack-edpm
spec:
  deployStrategy:
      deploy: false
  nodes:
    edpm-compute-0:
      role: edpm-compute
      hostName: edpm-compute-0
      ansibleHost: 172.22.0.100
      node:
        ansibleVars: |
          ctlplane_ip: 172.22.0.100
          internal_api_ip: 172.17.0.100
          storage_ip: 172.18.0.100
          tenant_ip: 172.19.0.100
          fqdn_internal_api: edpm-compute-0.example.com
        ansibleSSHPrivateKeySecret: dataplane-ansible-ssh-private-key-secret
$(if [[ $NODE_COUNT -eq 2 ]]; then
  cat <<SECOND_NODE_EOF
    edpm-compute-1:
      role: edpm-compute
      hostName: edpm-compute-1
      ansibleHost: 172.22.0.101
      node:
        ansibleVars: |
          ctlplane_ip: 172.22.0.101
          internal_api_ip: 172.17.0.101
          storage_ip: 172.18.0.101
          tenant_ip: 172.19.0.101
          fqdn_internal_api: edpm-compute-1.example.com
        ansibleSSHPrivateKeySecret: dataplane-ansible-ssh-private-key-secret
SECOND_NODE_EOF
fi)
  roles:
    edpm-compute:
      env:
        - name: ANSIBLE_FORCE_COLOR
          value: "True"
        - name: ANSIBLE_ENABLE_TASK_DEBUGGER
          value: "True"
        - name: ANSIBLE_VERBOSITY
          value: "2"
      baremetalSetTemplate:
        rhelImageUrl: ${RHEL_IMAGE_URL}
        provisioningInterface:  ${PROVISIONING_INTERFACE}
        deploymentSSHSecret: dataplane-ansible-ssh-private-key-secret
        ctlplaneInterface: enp1s0
        bmhNamespace: openstack
        ctlplaneGateway: ${NETWORK_IPADDRESS}
        ctlplaneNetmask: 255.255.255.0
        domainName: osptest.openstack.org
        bootstrapDns:
          - ${NETWORK_IPADDRESS}
        dnsSearchDomains:
          - osptest.openstack.org
      nodeTemplate:
        managementNetwork: ctlplane
        ansibleUser: cloud-admin
        ansiblePort: 22
        ansibleSSHPrivateKeySecret: dataplane-ansible-ssh-private-key-secret
        ansibleVars: |
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
          #
          # These vars are for the network config templates themselves and are
          # considered EDPM network defaults.
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

          edpm_ovn_controller_agent_image: quay.io/tripleozedcentos9/openstack-ovn-controller:current-tripleo
          edpm_iscsid_image: quay.io/tripleozedcentos9/openstack-iscsid:current-tripleo
          edpm_logrotate_crond_image: quay.io/tripleozedcentos9/openstack-cron:current-tripleo
          edpm_nova_compute_container_image: quay.io/tripleozedcentos9/openstack-nova-compute:current-tripleo
          edpm_nova_libvirt_container_image: quay.io/tripleozedcentos9/openstack-nova-libvirt:current-tripleo
          edpm_ovn_metadata_agent_image: quay.io/tripleozedcentos9/openstack-neutron-metadata-agent-ovn:current-tripleo

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
          hosts_entries: []
          hosts_entry: []
      deployStrategy:
        deploy: false
EOF
oc apply -f ${OUTPUT_DIR}
