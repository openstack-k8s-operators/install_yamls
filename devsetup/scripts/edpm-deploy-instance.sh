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

# Create Image
IMG=cirros-0.5.2-x86_64-disk.img
URL=http://download.cirros-cloud.net/0.5.2/$IMG
DISK_FORMAT=qcow2
RAW=$IMG
NUMBER_OF_INSTANCES=${1:-1}
curl -L -# $URL > /tmp/$IMG
if type qemu-img >/dev/null 2>&1; then
    RAW=$(echo $IMG | sed s/img/raw/g)
    qemu-img convert -f qcow2 -O raw /tmp/$IMG /tmp/$RAW
    DISK_FORMAT=raw
fi
openstack image show cirros || \
    openstack image create --container-format bare --disk-format $DISK_FORMAT cirros < /tmp/$RAW

# Create flavor
openstack flavor show m1.small || \
    openstack flavor create --ram 512 --vcpus 1 --disk 1 --ephemeral 1 m1.small

# Create networks
openstack network show private || openstack network create private --share
openstack subnet show priv_sub || openstack subnet create priv_sub --subnet-range 192.168.0.0/24 --network private
openstack network show public || openstack network create public --external --provider-network-type flat --provider-physical-network datacentre
openstack subnet show pub_sub || \
    openstack subnet create pub_sub --subnet-range 192.168.122.0/24 --allocation-pool start=192.168.122.200,end=192.168.122.210 --gateway 192.168.122.1 --no-dhcp --network public
openstack router show priv_router || {
    openstack router create priv_router
    openstack router add subnet priv_router priv_sub
    openstack router set priv_router --external-gateway public
}

# Create security group and icmp/ssh rules
openstack security group show basic || {
    openstack security group create basic
    openstack security group rule create basic --protocol icmp --ingress --icmp-type -1
    openstack security group rule create basic --protocol tcp --ingress --dst-port 22
}

# List External compute resources
openstack compute service list
openstack network agent list

# Create an instance
for (( i=0; i<${NUMBER_OF_INSTANCES}; i++ )); do
    NAME=test_${i}
    openstack server show ${NAME} || {
        openstack server create --flavor m1.small --image cirros --nic net-id=private ${NAME} --security-group basic --wait
        fip=$(openstack floating ip create public -f value -c floating_ip_address)
        openstack server add floating ip ${NAME} $fip
    }
    openstack server list --long

    # check connectivity via FIP
    ping -c4 $fip
done
