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

openstack undercloud install --no-validations
source stackrc

# TODO(bogdando): cells-specific DNS domains and neworks in network v2 data
if [ $EDPM_COMPUTE_CELLS -gt 1 ] ; then
    cp overcloud_services_cell0.yaml overcloud_services.yaml
    cp network_data0.yaml network_data.yaml
    cp vips_data0.yaml vips_data.yaml
    # For the time being, use the same network data (with network leafs) for all stacks we deploy
    for cell in $(seq 0 $(( EDPM_COMPUTE_CELLS - 1))); do
        [ $cell -eq 1 ] && continue
        cp network_data${cell}.yaml network_data${cell}_cells_specific_unused.yaml
        cp network_data1.yaml network_data${cell}.yaml
    done
    sed -i "s/overcloud/multistack/g" overcloud_services.yaml
fi

openstack overcloud network provision --output network_provision_out.yaml ./network_data.yaml
openstack overcloud network vip provision --stack overcloud --output vips_provision_out.yaml ./vips_data.yaml
if [ $EDPM_COMPUTE_CELLS -gt 1 ] ; then
    for cell in $(seq 1 $(( EDPM_COMPUTE_CELLS - 1))); do
        echo "provision networks and VIPs for cell $cell"
        openstack overcloud network provision --output network_provision_out${cell}.yaml ./network_data${cell}.yaml
        openstack overcloud network vip provision --stack cell${cell} --output vips_provision_out${cell}.yaml ./vips_data${cell}.yaml
    done
fi

# provide a default layout for local development envs outside of CI
test -f /home/zuul/hostnamemap.yaml || cat > /home/zuul/hostnamemap.yaml << EOF
parameter_defaults:
  HostnameMap:
    overcloud-controller-0: edpm-compute-1
    cell1-controller-0: edpm-compute-2
    cell1-compute-0: edpm-compute-3
    cell2-controller-compute-0: edpm-compute-4
EOF

# check if hostnamemap contains networkers
networker_nodes="FALSE"
config_download="config-download.yaml"
if (grep -q networker hostnamemap.yaml); then
    networker_nodes="TRUE"
    config_download="config-download-networker.yaml"
fi

# use default role name for ComputeHCI in hostnamemap
[ "$EDPM_COMPUTE_CEPH_ENABLED" = "true" ] && sed -i "s/-novacompute-/-computehci-/" hostnamemap.yaml

# update the config-download with proper overcloud hostnames
# TODO(bogdando): make config-download.yaml for standard multi-node single cell cases consistent with multstack scenarios,
# also providing both enough flexibility for local deployments, by j2 renderinig it (and hostnamemap.yaml) in tripleo.sh.
# We cannot j2 render it in tripleo.sh yet as hostnamemap.yaml is only provided for undercloud VM, where this script is executed.
set +e
control0=$(grep "overcloud-controller-0" hostnamemap.yaml  | awk '{print $2}')
if [ $EDPM_COMPUTE_CELLS -eq 1 ] ; then
    control0=$(grep "overcloud-controller-0" hostnamemap.yaml  | awk '{print $2}')
    control1=$(grep "overcloud-controller-1" hostnamemap.yaml  | awk '{print $2}')
    control2=$(grep "overcloud-controller-2" hostnamemap.yaml  | awk '{print $2}')
    sed -i "s/controller-0/${control0}/" $config_download
    sed -i "s/controller-1/${control1}/" $config_download
    sed -i "s/controller-2/${control2}/" $config_download
    compute0=$(grep -E "overcloud-(novacompute|computehci)-0" hostnamemap.yaml  | awk '{print $2}')
    compute1=$(grep -E "overcloud-(novacompute|computehci)-1" hostnamemap.yaml  | awk '{print $2}')
    sed -i "s/compute-0/${compute0}/" $config_download
    sed -i "s/compute-1/${compute1}/" $config_download

    if [ $networker_nodes == "FALSE" ]; then
        compute2=$(grep -E "overcloud-(novacompute|computehci)-2" hostnamemap.yaml  | awk '{print $2}')
        sed -i "s/compute-2/${compute2}/" $config_download
    elif [ $networker_nodes == "TRUE" ]; then
        networker0=$(grep "overcloud-networker-0" hostnamemap.yaml  | awk '{print $2}')
        networker1=$(grep "overcloud-networker-1" hostnamemap.yaml  | awk '{print $2}')
        sed -i "s/networker-0/${networker0}/" $config_download
        sed -i "s/networker-1/${networker1}/" $config_download
    fi
else
    compute0=$(grep "cell1-controller-0" hostnamemap.yaml  | awk '{print $2}')
    compute1=$(grep "cell1-compute-0" hostnamemap.yaml  | awk '{print $2}')
    compute2=$(grep "cell2-controller-compute-0" hostnamemap.yaml  | awk '{print $2}')
    sed -i "s/ controller-0/ ${control0}/" config-download-cell0.yaml
    sed -i "s/ compute-0/ ${compute0}/" config-download-cell1.yaml
    sed -i "s/ compute-1/ ${compute1}/" config-download-cell1.yaml
    sed -i "s/ compute-2/ ${compute2}/" config-download-cell2.yaml
fi
set -e

# read all the contents of hostnamemap except the yaml separator into one line
hostnamemap=$(grep -v "\---" hostnamemap.yaml | tr '\n' '\r')
hostnamemap="$hostnamemap\r  ControllerHostnameFormat: '%stackname%-controller-%index%'\r"
if [ "$EDPM_COMPUTE_CEPH_ENABLED" = "true" ] ; then
    # add hci role for ceph nodes
    hostnamemap="$hostnamemap\r  ComputeHCIHostnameFormat: '%stackname%-computehci-%index%'"
fi

if [ $networker_nodes == "TRUE" ]; then
    cdfiles=($(ls -1 config-download-networker*.yaml))
else
    cdfiles=($(ls -1 config-download*.yaml | grep -v config-download-networker))
fi

for config_download in ${cdfiles[@]}; do
    if [ "$EDPM_COMPUTE_CEPH_ENABLED" = "true"  ] ; then
        # insert hostnamemap contents into config-download.yaml, we need it to generate
        # the inventory for ceph deployment
        sed -i "s/parameter_defaults:/${hostnamemap}/" "$config_download"

        # swap computes for compute hci
        sed -i "s/::Compute::/::ComputeHCI::/" $config_download
        # add storage management port to compute hci nodes
        stg_line="OS::TripleO::ComputeHCI::Ports::StoragePort: /usr/share/openstack-tripleo-heat-templates/network/ports/deployed_storage.yaml"
        stg_mgmt_line="OS::TripleO::ComputeHCI::Ports::StorageMgmtPort: /usr/share/openstack-tripleo-heat-templates/network/ports/deployed_storage_mgmt.yaml"
        sed -i "s#$stg_line#$stg_line\r  $stg_mgmt_line\r#" $config_download
        # correct RoleCount var in overcloud_services
        sed -i "s/ComputeCount/ComputeHCICount/" overcloud_services.yaml
    fi
    # Remove any quotes e.g. "np10002"-ctlplane -> np10002-ctlplane
    sed -i 's/\"//g' "$config_download"
    # re-add newlines
    sed -i "s/\r/\n/g" "$config_download"
    # remove empty lines
    sed -i "/^$/d" "$config_download"
done

# Add Manila bits
MANILA_ENABLED=${MANILA_ENABLED:-true}
if [ "$MANILA_ENABLED" = "true" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/manila-cephfsnative-config.yaml"
fi
# Add octavia bits
OCTAVIA_ENABLED=${OCTAVIA_ENABLED:-false}
if [ "$OCTAVIA_ENABLED" = "true" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/octavia.yaml"
fi

TELEMETRY_ENABLED=${TELEMETRY_ENABLED:-true}
if [ "$TELEMETRY_ENABLED" = "true" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/enable-legacy-telemetry.yaml"
fi

# defaults for non-ceph case
CEPH_OVERCLOUD_ARGS=""
ROLES_FILE="/home/zuul/overcloud_roles.yaml"
if [ "$EDPM_COMPUTE_CEPH_ENABLED" = "true" ] ; then
    # create roles file
    cp $ROLES_FILE roles.yaml
    openstack overcloud roles generate ComputeHCI >> roles.yaml
    ROLES_FILE=roles.yaml
fi
if [ "$TRIPLEO_NETWORKING" != "true" ] ; then
    # disable external gateway for controller nodes
    sed -i "s/default_route_networks: \['External'\]/default_route_networks: \['ControlPlane'\]/" $ROLES_FILE
    sed -i "/External:/d" $ROLES_FILE
    sed -i "/subnet: external_subnet/d" $ROLES_FILE
fi
if [ "$EDPM_COMPUTE_CEPH_ENABLED" = "true" ] ; then
    CEPH_OVERCLOUD_ARGS="${CEPH_ARGS}"
    [[ "$MANILA_ENABLED" == "true" ]] && CEPH_OVERCLOUD_ARGS+=' -e /usr/share/openstack-tripleo-heat-templates/environments/cephadm/ceph-mds.yaml'
    /tmp/ceph.sh
fi

if [ "$TLSE_ENABLED" = "true" ]; then
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/ssl/tls-everywhere-endpoints-dns.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/haproxy-public-tls-certmonger.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/ssl/enable-internal-tls.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/ssl/enable-memcached-tls.yaml"
    ENV_ARGS+=" -e /usr/share/openstack-tripleo-heat-templates/ci/environments/standalone-ipa.yaml"
    export IPA_ADMIN_USER=admin
    export IPA_PRINCIPAL=$IPA_ADMIN_USER
    export IPA_ADMIN_PASSWORD=fce95318204114530f31f885c9df588f
    export IPA_PASSWORD=$IPA_ADMIN_PASSWORD
    export UNDERCLOUD_FQDN=undercloud.$CLOUD_DOMAIN
    export IPA_DOMAIN=$CLOUD_DOMAIN
    export IPA_REALM=$(echo $IPA_DOMAIN | awk '{print toupper($0)}')
    export IPA_HOST=ipa.$IPA_DOMAIN
    export IPA_SERVER_HOSTNAME=$IPA_HOST
    sudo mkdir /tmp/ipa-data
    sudo podman run -d --name freeipa-server-container \
        --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
        --security-opt seccomp=unconfined \
        --ip 10.255.255.25 \
        -e IPA_SERVER_IP=10.255.255.25 \
        -e PASSWORD=$IPA_ADMIN_PASSWORD \
        -h $IPA_SERVER_HOSTNAME \
        -p 53:53/udp -p 53:53 -p 80:80 -p 443:443 \
        -p 389:389 -p 636:636 -p 88:88 -p 464:464 \
        -p 88:88/udp -p 464:464/udp \
        --read-only --tmpfs /run --tmpfs /tmp \
        -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
        -v /tmp/ipa-data:/data:Z quay.io/freeipa/freeipa-server:fedora-39 no-exit \
        -U -r $IPA_REALM --setup-dns --no-reverse --no-ntp \
        --no-dnssec-validation --auto-forwarders
    timeout 900s grep -qEi '(INFO The ipa-server-install command was successful|ERROR The ipa-server-install command failed)' <(sudo tail -F /tmp/ipa-data/var/log/ipaserver-install.log)
    # NOTE: the ipa_resolv.conf has already been setup on overcloud nodes
    # see rdo-jobs playbooks/data_plane_adoption/deploy_tripleo_run_repo_tests.yaml
    cat  <<EOF > ipa_resolv.conf
search ${CLOUD_DOMAIN}
nameserver 10.255.255.25
EOF
    sudo mv ipa_resolv.conf /etc/resolv.conf
    ansible-playbook /usr/share/ansible/tripleo-playbooks/undercloud-ipa-install.yaml
fi

openstack overcloud deploy --stack overcloud \
    --override-ansible-cfg /home/zuul/ansible_config.cfg --templates /usr/share/openstack-tripleo-heat-templates \
    --roles-file ${ROLES_FILE} -n /home/zuul/network_data.yaml --libvirt-type qemu \
    --ntp-server ${NTP_SERVER} \
    --timeout 90 --overcloud-ssh-user zuul --deployed-server \
    -e /home/zuul/hostnamemap.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/docker-ha.yaml \
    -e /home/zuul/containers-prepare-parameters.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/podman.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/debug.yaml --validation-warnings-fatal ${ENV_ARGS} ${CEPH_OVERCLOUD_ARGS} \
    -e /home/zuul/overcloud_services.yaml -e /home/zuul/${cdfiles[0]} \
    -e /home/zuul/vips_provision_out.yaml -e /home/zuul/network_provision_out.yaml --disable-validations --heat-type pod \
    --disable-protected-resource-types --log-file overcloud_deployment.log
if [ $EDPM_COMPUTE_CELLS -gt 1 ] ; then
    # FIXME(bogdando): w/a OSP17.1 https://bugzilla.redhat.com/show_bug.cgi?id=2294898 until the fix merged and shipped
    sudo dnf install -y patch
    cd /usr/share/ansible
    cat > /tmp/patch << EOF
--- a/tripleo-playbooks/create-nova-cell-v2.yaml
+++ b/tripleo-playbooks/create-nova-cell-v2.yaml
@@ -21,22 +21,23 @@
     tripleo_cellv2_cell_name: "{{ tripleo_cellv2_cell_name }}"
     # containercli can be tropped when we fully switched to podman
     tripleo_cellv2_containercli: "{{ tripleo_cellv2_containercli }}"
-    tripleo_cellv2_cellcontroller_group: "{{ groups['CellController'] }}"
   tasks:
     - import_role:
         name: tripleo_cellv2
         tasks_from: check_cell_exist.yml

-- hosts: CellController[0]
+- hosts: Controller[0]
   remote_user: stack
-  gather_facts: true
+  gather_facts: false
   vars:
     tripleo_cellv2_cell_name: "{{ tripleo_cellv2_cell_name }}"
     # containercli can be tropped when we fully switched to podman
     tripleo_cellv2_containercli: "{{ tripleo_cellv2_containercli }}"
-    tripleo_cellv2_cellcontroller_group: "{{ groups['CellController'] }}"
+    tripleo_cellv2_cellcontroller_group: "{{ groups[tripleo_cellv2_cell_name ~ '_' ~ tripleo_cellv2_cellcontroller_rolename] }}"
   tasks:
-    - import_role:
+    - delegate_to: "{{ tripleo_cellv2_cellcontroller_group[0] }}"
+      delegate_facts: false
+      import_role:
         name: tripleo_cellv2
         tasks_from: extract_cell_information.yml

@@ -47,7 +48,7 @@
     tripleo_cellv2_cell_name: "{{ tripleo_cellv2_cell_name }}"
     # containercli can be tropped when we fully switched to podman
     tripleo_cellv2_containercli: "{{ tripleo_cellv2_containercli }}"
-    tripleo_cellv2_cellcontroller_group: "{{ groups['CellController'] }}"
+    tripleo_cellv2_cellcontroller_group: "{{ groups[tripleo_cellv2_cell_name ~ '_' ~ tripleo_cellv2_cellcontroller_rolename] }}"
   tasks:
     - import_role:
         name: tripleo_cellv2

--- a/roles/tripleo_cellv2/defaults/main.yml
+++ b/roles/tripleo_cellv2/defaults/main.yml
@@ -18,10 +18,11 @@
 # All variables intended for modification should be placed in this file.

 tripleo_cellv2_debug: "{{ (ansible_verbosity | int) >= 2 | bool }}"
-tripleo_cellv2_cell_name: ""
+tripleo_cellv2_cell_name: "cell1"
 # containercli can be tropped when we fully switched to podman
 tripleo_cellv2_containercli: "docker"

-tripleo_cellv2_cellcontroller_group: "{{ groups['CellController'] }}"
-tripleo_cellv2_cell_database_vip: "{{ hostvars[tripleo_cellv2_cellcontroller_group[0]]['cell_database_vip'] }}"
-tripleo_cellv2_cell_transport_url: "{{ hostvars[tripleo_cellv2_cellcontroller_group[0]]['cell_transport_url'] }}"
+tripleo_cellv2_cellcontroller_rolename: "CellController"
+tripleo_cellv2_cellcontroller_group: "{{ groups[tripleo_cellv2_cellcontroller_rolename] }}"
+tripleo_cellv2_cell_database_vip: ""
+tripleo_cellv2_cell_transport_url: ""

--- a/roles/tripleo_cellv2/tasks/create_cell.yml
+++ b/roles/tripleo_cellv2/tasks/create_cell.yml
@@ -21,8 +21,8 @@
     shell: >-
       {{ tripleo_cellv2_containercli }} exec -i -u root nova_api
       nova-manage cell_v2 create_cell --name {{ tripleo_cellv2_cell_name }}
-      --database_connection "{scheme}://{username}:{password}@{{ tripleo_cellv2_cell_database_vip }}/nova?{query}"
-      --transport-url "{{ tripleo_cellv2_cell_transport_url }}"
+      --database_connection "{scheme}://{username}:{password}@{{ tripleo_cellv2_cell_database_vip | default(cell_database_vip, true) }}/nova?{query}"
+      --transport-url "{{ tripleo_cellv2_cell_transport_url | default(cell_transport_url, true) }}"

   - name: List Cells
     shell: >
EOF
    sudo patch -p1 < /tmp/patch
    cd -

    mkdir -p /home/zuul/inventories
    cp /home/zuul/overcloud-deploy/overcloud/config-download/overcloud/tripleo-ansible-inventory.yaml /home/zuul/inventories/overcloud.yaml
    export OS_CLOUD=overcloud
    for cell in $(seq 1 $(( EDPM_COMPUTE_CELLS - 1))); do
        echo "extract deployment data for cell $cell"
        openstack overcloud cell export --control-plane-stack overcloud -f --output-file /home/zuul/cell${cell}-input.yaml --working-dir /home/zuul/overcloud-deploy/overcloud/

        echo "deploy cell $cell"
        openstack overcloud deploy --stack cell${cell} \
            --override-ansible-cfg /home/zuul/ansible_config.cfg --templates /usr/share/openstack-tripleo-heat-templates \
            --roles-file ${ROLES_FILE} -n /home/zuul/network_data${cell}.yaml --libvirt-type qemu \
            --ntp-server ${NTP_SERVER} \
            --timeout 90 --overcloud-ssh-user zuul --deployed-server \
            -e /home/zuul/hostnamemap.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/docker-ha.yaml \
            -e /home/zuul/containers-prepare-parameters.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/podman.yaml \
            -e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml \
            -e /usr/share/openstack-tripleo-heat-templates/environments/debug.yaml --validation-warnings-fatal ${CEPH_OVERCLOUD_ARGS} \
            -e /home/zuul/overcloud_services_cell${cell}.yaml -e /home/zuul/${cdfiles[$cell]} -e /home/zuul/cell${cell}-input.yaml \
            -e /home/zuul/vips_provision_out${cell}.yaml -e /home/zuul/network_provision_out${cell}.yaml --disable-validations --heat-type pod \
            --disable-protected-resource-types --log-file cell${cell}_deployment.log

        echo "create cell $cell and discover compute hosts"
        cp /home/zuul/overcloud-deploy/cell${cell}/config-download/cell${cell}/tripleo-ansible-inventory.yaml \
            /home/zuul/inventories/cell${cell}.yaml
        export ANSIBLE_HOST_KEY_CHECKING=False
        export ANSIBLE_SSH_RETRIES=3
        ansible -bi /home/zuul/inventories -m ansible.builtin.package -a "name=crudini" all

        # Get a proper cell controller role name to use for a cell creation
        groupname=CellController
        if ansible -i /home/zuul/inventories -m debug -a "var=groups['cell${cell}_${groupname}']" undercloud | grep -q "VARIABLE IS NOT DEFINED!" ; then
            groupname=CellControllerCompute
        fi

        ansible-playbook -i /home/zuul/inventories \
            /usr/share/ansible/tripleo-playbooks/create-nova-cell-v2.yaml \
                -e tripleo_cellv2_cell_name=cell${cell} \
                -e tripleo_cellv2_containercli=podman \
                -e tripleo_cellv2_cellcontroller_rolename=$groupname

        echo "add cell $cell compute hosts to aggregates"
        openstack aggregate create cell${cell} --zone cell${cell}
        for i in $(openstack hypervisor list -f value -c 'Hypervisor Hostname'| grep cell${cell}); do
            openstack aggregate add host cell${cell} $i
        done
    done

    echo "ensure /etc/hosts records are up-to-date in the main stack"
    ANSIBLE_REMOTE_USER="tripleo-admin" ansible allovercloud \
        -i /home/zuul/inventories -m include_role \
        -a name=tripleo_hosts_entries \
        -e hostname_resolve_network=ctlplane -e plan=overcloud \
        -e @/home/zuul/overcloud-deploy/overcloud/config-download/overcloud/global_vars.yaml
fi
