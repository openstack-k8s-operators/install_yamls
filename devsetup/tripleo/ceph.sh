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

# generate inventory based on config-download.yaml
mkdir -p $HOME/overcloud-deploy/overcloud/
export INV=$HOME/overcloud-deploy/overcloud/tripleo-ansible-inventory.yaml
python /tmp/generate_ceph_inventory.py -d config-download.yaml -i $INV

# in CI we'll copy ci-framework from the controller node, so we can pickup
# depends-on, but this block makes sure we have ci-framework in case this runs
# outside
if [[ ! -d "$HOME/ci-framework" ]]; then
    git clone https://github.com/openstack-k8s-operators/ci-framework.git
fi

cd ci-framework
# create block devices on all compute nodes
ansible-playbook -i $INV playbooks/ceph.yml --tags block -e num_osds=3
cd ..

cat <<EOF > osd_spec.yaml
data_devices:
  paths:
    - /dev/ceph_vg0/ceph_lv0
    - /dev/ceph_vg1/ceph_lv1
    - /dev/ceph_vg2/ceph_lv2
EOF

# create roles file
openstack overcloud roles generate Controller ComputeHCI > roles.yaml

# disable external gateway for controller nodes
sed -i "s/default_route_networks: \['External'\]/default_route_networks: \['ControlPlane'\]/" roles.yaml
sed -i "/External:/d" roles.yaml
sed -i "/subnet: external_subnet/d" roles.yaml

# generate ceph_spec file
openstack overcloud ceph spec config-download.yaml \
    --tld localdomain \
    --osd-spec osd_spec.yaml \
    --roles-data roles.yaml \
    -o ceph_spec.yaml

# deploy ceph
openstack overcloud ceph deploy \
    --tld localdomain \
    --ceph-spec ceph_spec.yaml \
    --network-data network_data.yaml \
    --cephadm-default-container \
    --output deployed_ceph.yaml \
    --config initial-ceph.conf # TODO: jgilaber only required have ceph working with only 1 compute node should remove it once we move to have 3 computes
