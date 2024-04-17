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

openstack undercloud install
source stackrc

openstack overcloud network provision --output network_provision_out.yaml ./network_data.yaml
openstack overcloud network vip provision --stack overcloud --output vips_provision_out.yaml ./vips_data.yaml

# update the config-download with proper overcloud hostnames
control0=$(grep "overcloud-controller-0" hostnamemap.yaml  | awk '{print $2}')
control1=$(grep "overcloud-controller-1" hostnamemap.yaml  | awk '{print $2}')
control2=$(grep "overcloud-controller-2" hostnamemap.yaml  | awk '{print $2}')
compute0=$(grep "overcloud-novacompute-0" hostnamemap.yaml  | awk '{print $2}')
sed -i "s/controller-0/${control0}/" config-download.yaml
sed -i "s/controller-1/${control1}/" config-download.yaml
sed -i "s/controller-2/${control2}/" config-download.yaml
sed -i "s/compute-0/${compute0}/" config-download.yaml
# Remove any quotes e.g. "np10002"-ctlplane -> np10002-ctlplane
sed -i 's/\"//g' config-download.yaml

openstack overcloud deploy --stack overcloud \
    --override-ansible-cfg /home/zuul/ansible_config.cfg --templates /usr/share/openstack-tripleo-heat-templates \
    --roles-file /home/zuul/overcloud_roles.yaml -n /home/zuul/network_data.yaml --libvirt-type qemu \
    --ntp-server 0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org,3.pool.ntp.org \
    --timeout 90 --overcloud-ssh-user zuul --deployed-server \
    -e /home/zuul/hostnamemap.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/docker-ha.yaml \
    -e /home/zuul/containers-prepare-parameters.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/podman.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/debug.yaml --validation-warnings-fatal \
    -e /home/zuul/overcloud_services.yaml -e /home/zuul/config-download.yaml \
    -e /home/zuul/vips_provision_out.yaml -e /home/zuul/network_provision_out.yaml --disable-validations --heat-type pod \
    --disable-protected-resource-types
