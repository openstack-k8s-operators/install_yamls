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

. $HOME/.standalone_env_file

# Use the files created in the previous steps including the network_data.yaml file and thw deployed_network.yaml file.
# The deployed_network.yaml file hard codes the IPs and VIPs configured from the network.sh

export NEUTRON_INTERFACE=eth0
export CTLPLANE_IP=${IP:-192.168.122.100}
export CTLPLANE_VIP=${CTLPLANE_IP%.*}.99
export CIDR=24
export GATEWAY=${GATEWAY:-192.168.122.1}
export BRIDGE="br-ctlplane"
if [ "$COMPUTE_DRIVER" = "ironic" ]; then
    BRIDGE_MAPPINGS=${BRIDGE_MAPPINGS:-"datacentre:${BRIDGE},baremetal:br-baremetal"}
    NEUTRON_FLAT_NETWORKS=${NEUTRON_FLAT_NETWORKS:-"datacentre,baremetal"}
else
    BRIDGE_MAPPINGS=${BRIDGE_MAPPINGS:-"datacentre:${BRIDGE}"}
    NEUTRON_FLAT_NETWORKS=${NEUTRON_FLAT_NETWORKS:-"datacentre"}
fi

# Create standalone_parameters.yaml file and deploy standalone OpenStack using the following commands.
cat <<EOF > standalone_parameters.yaml
parameter_defaults:
  CloudName: $CTLPLANE_IP
  Debug: true
  DeploymentUser: $USER
  NtpServer: $NTP_SERVER
  # needed for vip & pacemaker
  KernelIpNonLocalBind: 1
  DockerInsecureRegistryAddress:
  - $CTLPLANE_IP:8787
  NeutronPublicInterface: $NEUTRON_INTERFACE
  # domain name used by the host
  NeutronDnsDomain: localdomain
  # re-use ctlplane bridge for public net
  NeutronBridgeMappings: $BRIDGE_MAPPINGS
  NeutronPhysicalBridge: $BRIDGE
  NeutronFlatNetworks: $NEUTRON_FLAT_NETWORKS
  StandaloneEnableRoutedNetworks: false
  StandaloneHomeDir: $HOME
  InterfaceLocalMtu: ${INTERFACE_MTU}
  # Needed if running in a VM
  ValidateGatewaysIcmp: false
  ValidateControllersIcmp: false
  OctaviaAmphoraSshKeyFile: /root/.ssh/id_ecdsa.pub
  OctaviaGenerateCerts: true
  OctaviaLogOffload: true
  OctaviaForwardAllLogs: true
  StandaloneNetworkConfigTemplate: $HOME/standalone_net_config.j2
  ServiceNetMap:
    IronicNetwork: baremetal
    IronicInspectorNetwork: baremetal
EOF

CMD="openstack tripleo deploy"

if [[ "$EDPM_COMPUTE_SUFFIX" == "0"  ]]; then
    CMD_ARGS+=" --keep-running"
fi
CMD_ARGS+=" --templates /usr/share/openstack-tripleo-heat-templates"
CMD_ARGS+=" --local-ip=$CTLPLANE_IP/$CIDR"
CMD_ARGS+=" --control-virtual-ip=$CTLPLANE_VIP"
CMD_ARGS+=" --output-dir $HOME"
CMD_ARGS+=" --standalone-role Standalone"
CMD_ARGS+=" -r $HOME/Standalone.yaml"
CMD_ARGS+=" -n $HOME/network_data.yaml"

ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/standalone/standalone-tripleo.yaml"
ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml"
ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/deployed-network-environment.yaml"
if [ "$COMPUTE_DRIVER" = "ironic" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/ironic-overcloud.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/ironic-inspector.yaml"
fi
ENV_ARGS+=" -e $HOME/standalone_parameters.yaml"
if [ "$EDPM_COMPUTE_CEPH_ENABLED" = "true" ] ; then
    CEPH_ARGS=${CEPH_ARGS:-"-e ~/deployed_ceph.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/cephadm/cephadm-rbd-only.yaml"}
    ENV_ARGS+=" ${CEPH_ARGS}"
fi

# NOTE: For other nodes than node0, deploy it as extra Heat stacks,
# by using env files prepared after the standalone node0.
# See https://docs.openstack.org/project-deploy-guide/tripleo-docs/wallaby/deployment/standalone.html#deploy-the-remote-compute-node
EDGE="$HOME/edge${EDPM_COMPUTE_SUFFIX}"
if [[ "$EDPM_COMPUTE_SUFFIX" != "0"  ]]; then
    sed -ir "s/edge0/edge${EDPM_COMPUTE_SUFFIX}/g" ${EDGE}_services.yaml
    ENV_ARGS+=" -e ${EDGE}_services.yaml"
    ENV_ARGS+=" -e ${EDGE}_endpoint-map.json"
    ENV_ARGS+=" -e ${EDGE}_net-ip-map.json"
    ENV_ARGS+=" -e ${EDGE}_all-nodes-extra-map-data.json"
    ENV_ARGS+=" -e ${EDGE}_extra-host-file-entries.json"
    ENV_ARGS+=" -e ${EDGE}_oslo.json"
fi
ENV_ARGS+=" -e $HOME/containers-prepare-parameters.yaml"
ENV_ARGS+=" -e $HOME/deployed_network.yaml"

sudo ${CMD} ${CMD_ARGS} ${ENV_ARGS}

# NOTE: after node0 deployed, extract env files for multi-stack standalone deployments
if [[ "$EDPM_COMPUTE_SUFFIX" == "0"  ]]; then
    unset OS_CLOUD
    export OS_AUTH_TYPE=none
    export OS_ENDPOINT=http://127.0.0.1:8006/v1/admin
    export OS_CLOUDNAME=heat
    STANDALONE_LATEST=$(find ~/standalone-ansible-* -type d -printf "%T@ %p\n" | sort -n | cut -d' ' -f 2- | tail -n 1)
    set +e
    openstack stack output show standalone EndpointMap --format json
    if [ $? -ne 0 ]; then
        set -e
        HEAT_LATEST=$(find ~/heat_launcher* -type d -printf "%T@ %p\n" | sort -n | cut -d' ' -f 2- | tail -n 1)
        pkill -f /usr/bin/heat-all
        openstack tripleo launch heat --restore-db --heat-dir="$HEAT_LATEST" --heat-type=native
        cd $HEAT_LATEST
    fi

    openstack stack output show standalone EndpointMap --format json \
    | jq '{"parameter_defaults": {"EndpointMapOverride": .output_value}}' \
    > ${EDGE}_endpoint-map.json

    openstack stack output show standalone EndpointMap --format json \
    | jq '{"parameter_defaults": {"RoleNetIpMap": .output_value}}' \
    > ${EDGE}_net-ip-map.json

    openstack stack output show standalone HostsEntry -f json \
    | jq -r '{"parameter_defaults":{"ExtraHostFileEntries": .output_value}}' \
    > ${EDGE}_extra-host-file-entries.json

    jq '.' $STANDALONE_LATEST/group_vars/overcloud.json \
    | jq -n '.parameter_defaults.AllNodesExtraMapData=inputs' - \
    > ${EDGE}_all-nodes-extra-map-data.json

    cat <<EOF > ${EDGE}_services.yaml
resource_registry:
    OS::TripleO::Services::CACerts: OS::Heat::None
    OS::TripleO::Services::CinderApi: OS::Heat::None
    OS::TripleO::Services::CinderScheduler: OS::Heat::None
    OS::TripleO::Services::Clustercheck: OS::Heat::None
    OS::TripleO::Services::HAproxy: OS::Heat::None
    OS::TripleO::Services::Horizon: OS::Heat::None
    OS::TripleO::Services::Keystone: OS::Heat::None
    OS::TripleO::Services::Memcached: OS::Heat::None
    OS::TripleO::Services::MySQL: OS::Heat::None
    OS::TripleO::Services::NeutronApi: OS::Heat::None
    OS::TripleO::Services::NeutronDhcpAgent: OS::Heat::None
    OS::TripleO::Services::NovaApi: OS::Heat::None
    OS::TripleO::Services::NovaConductor: OS::Heat::None
    OS::TripleO::Services::NovaConsoleauth: OS::Heat::None
    OS::TripleO::Services::NovaIronic: OS::Heat::None
    OS::TripleO::Services::NovaMetadata: OS::Heat::None
    OS::TripleO::Services::NovaPlacement: OS::Heat::None
    OS::TripleO::Services::NovaScheduler: OS::Heat::None
    OS::TripleO::Services::NovaVncProxy: OS::Heat::None
    OS::TripleO::Services::OsloMessagingNotify: OS::Heat::None
    OS::TripleO::Services::OsloMessagingRpc: OS::Heat::None
    OS::TripleO::Services::Redis: OS::Heat::None
    OS::TripleO::Services::SwiftProxy: OS::Heat::None
    OS::TripleO::Services::SwiftStorage: OS::Heat::None
    OS::TripleO::Services::SwiftRingBuilder: OS::Heat::None

parameter_defaults:
    CinderRbdAvailabilityZone: edge${EDPM_COMPUTE_SUFFIX}
    GlanceBackend: swift
    GlanceCacheEnabled: true
EOF

    cat <<EOF > ${EDGE}_oslo.json
{
    "parameter_defaults": {
        "StandaloneExtraConfig": {
            "oslo_messaging_notify_use_ssl": false,
            "oslo_messaging_rpc_use_ssl": false
        }
    }
}
EOF

    sudo jq ".parameter_defaults.StandaloneExtraConfig.oslo_messaging_notify_password=\
    \"$(jq -r '.oslo_messaging_notify_password' /etc/puppet/hieradata/service_configs.json)\"" \
    ${EDGE}_oslo.json \
    | jq ".parameter_defaults.StandaloneExtraConfig.oslo_messaging_rpc_password=\
    \"$(jq -r '.oslo_messaging_rpc_password' /etc/puppet/hieradata/service_configs.json)\"" \
    > ${EDGE}_oslo_.json
    mv -f ${EDGE}_oslo_.json ${EDGE}_oslo.json
fi