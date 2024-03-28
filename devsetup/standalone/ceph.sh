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

# These steps are based on TripleO Standalone to configure Ceph on the Standalone node to simulate an HCI or internal Ceph adoption.
# Ceph will be configured to use the Storage network (vlan21) and Storage Management network (vlan23).
# The storage management network, is not configured by default in an NG environment and does not need to be accessed by the NG environment
# as it is only used by Ceph (AKA the cluster_network) to make OSD replicas and NG will not be deploying Ceph.
# Post adoption this network will remain isolated and the Ceph cluster may be considered external.

# Assign the IP from vlan21 to a variable representing the Ceph IP
export CEPH_IP=${CEPH_IP:-"172.18.0.100"}

# Create a block device with logical volumes to be used as an OSD.
sudo dd if=/dev/zero of=/var/lib/ceph-osd.img bs=1 count=0 seek=7G
sudo losetup /dev/loop3 /var/lib/ceph-osd.img
sudo pvcreate /dev/loop3
sudo vgcreate vg2 /dev/loop3
sudo lvcreate -n data-lv2 -l +100%FREE vg2

# Persist the created device to restore it on startup.
cat > /tmp/ceph-osd-losetup.service << EOF
[Unit]
Description=Ceph OSD losetup
After=syslog.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/sbin/losetup /dev/loop3 || \
/sbin/losetup /dev/loop3 /var/lib/ceph-osd.img ; partprobe /dev/loop3'
ExecStop=/sbin/losetup -d /dev/loop3
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
cat /tmp/ceph-osd-losetup.service | sudo tee /etc/systemd/system/ceph-osd-losetup.service
sudo chmod 0644 /etc/systemd/system/ceph-osd-losetup.service
sudo systemctl daemon-reload
sudo systemctl enable --now ceph-osd-losetup.service

# Create an OSD spec file which references the block device.
cat <<EOF > $HOME/osd_spec.yaml
data_devices:
  paths:
    - /dev/vg2/data-lv2
EOF

# Use the Ceph IP and OSD spec file to create a Ceph spec file which will describe the Ceph cluster in a format cephadm can parse.
sudo openstack overcloud ceph spec \
    --standalone \
    --mon-ip $CEPH_IP \
    --osd-spec $HOME/osd_spec.yaml \
    --output $HOME/ceph_spec.yaml

# Create the ceph-admin user by passing the Ceph spec created earlier.
sudo openstack overcloud ceph user enable \
    --standalone \
    $HOME/ceph_spec.yaml

# Though Ceph will be configured to run on a single host via the --single-host-defaults option,
# this deployment only has a single OSD so it cannot replicate data even on the same host.
# Create an initial Ceph configuration to disable replication:
cat <<EOF > $HOME/initial_ceph.conf
[global]
osd pool default size = 1
[mon]
mon_warn_on_pool_no_redundancy = false
EOF

# Use the files created in the previous steps to install Ceph.
# Use thw network_data.yaml file so that Ceph uses the isolated networks for storage and storage management.
sudo openstack overcloud ceph deploy \
    --mon-ip $CEPH_IP \
    --ceph-spec $HOME/ceph_spec.yaml \
    --config $HOME/initial_ceph.conf \
    --container-image-prepare $HOME/containers-prepare-parameters.yaml \
    --standalone \
    --single-host-defaults \
    --skip-hosts-config \
    --skip-container-registry-config \
    --skip-user-create \
    --network-data /tmp/network_data.yaml \
    --ntp-server $NTP_SERVER \
    --output $HOME/deployed_ceph.yaml

# Ceph should now be installed. Use sudo cephadm shell -- ceph -s to confirm the Ceph cluster health.
