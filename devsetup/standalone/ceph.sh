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
export CEPH_IP=${CEPH_IP:-"172.18.0.100"}

sudo dd if=/dev/zero of=/var/lib/ceph-osd.img bs=1 count=0 seek=7G
sudo losetup /dev/loop3 /var/lib/ceph-osd.img
sudo pvcreate /dev/loop3
sudo vgcreate vg2 /dev/loop3
sudo lvcreate -n data-lv2 -l +100%FREE vg2

cat <<EOF > $HOME/osd_spec.yaml
data_devices:
  paths:
    - /dev/vg2/data-lv2
EOF

sudo openstack overcloud ceph spec \
    --standalone \
    --mon-ip $CEPH_IP \
    --osd-spec $HOME/osd_spec.yaml \
    --output $HOME/ceph_spec.yaml

sudo openstack overcloud ceph user enable \
    --standalone \
    $HOME/ceph_spec.yaml

cat <<EOF > $HOME/initial_ceph.conf
[global]
osd pool default size = 1
[mon]
mon_warn_on_pool_no_redundancy = false
EOF

sudo openstack overcloud ceph deploy \
    --mon-ip $CEPH_IP \
    --ceph-spec $HOME/ceph_spec.yaml \
    --config $HOME/initial_ceph.conf \
    --standalone \
    --single-host-defaults \
    --skip-hosts-config \
    --skip-container-registry-config \
    --skip-user-create \
    --network-data /tmp/network_data.yaml \
    --ntp-server $NTP_SERVER \
    --output $HOME/deployed_ceph.yaml
