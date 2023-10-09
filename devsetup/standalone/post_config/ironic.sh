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

export OS_CLOUD="standalone"
IRONIC_PYTHON_AGENT_URI=${IRONIC_PYTHON_AGENT_URI:-"https://images.rdoproject.org/centos9/master/rdo_trunk/current-tripleo/ironic-python-agent.tar"}
SUBNET_RANGE=${SUBNET_RANGE:-"172.20.1.0/24"}
SUBNET_GATEWAY=${SUBNET_GATEWAY:-"172.20.1.1"}
SUBNET_ALLOC_POOL_START=${SUBNET_ALLOC_POOL_START:-"172.20.1.200"}
SUBNET_ALLOC_POOL_END=${SUBNET_ALLOC_POOL_END:-"172.20.1.250"}


function deploy_images {
    mkdir -p $HOME/images
    pushd $HOME/images
    curl -o ironic-python-agent.tar.gz ${IRONIC_PYTHON_AGENT_URI}
    tar xvf ironic-python-agent.tar.gz
    sudo cp ironic-python-agent.kernel /var/lib/ironic/httpboot/agent.kernel
    sudo cp ironic-python-agent.initramfs /var/lib/ironic/httpboot/agent.ramdisk
    popd


    openstack image create deploy-kernel \
        --public \
        --container-format aki \
        --disk-format aki \
        --file $HOME/images/ironic-python-agent.kernel
    openstack image create deploy-ramdisk \
        --public \
        --container-format ari \
        --disk-format ari \
        --file $HOME/images/ironic-python-agent.initramfs
}


function provisioning_network {
    openstack network create provisioning \
        --share \
        --provider-physical-network baremetal \
        --provider-network-type flat
    openstack subnet create provisioning-subnet \
        --network provisioning \
        --subnet-range ${SUBNET_RANGE} \
        --gateway ${SUBNET_GATEWAY} \
        --allocation-pool start=${SUBNET_ALLOC_POOL_START},end=${SUBNET_ALLOC_POOL_END}
}


deploy_images
provisioning_network
