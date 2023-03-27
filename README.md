# k8s yaml generator/installer for Cloud Native OpenStack

The main purpose is to provide scripts to automate installing OpenStack in your *pre-installed* OpenShift environment.

Aside from generating Yaml and running *oc* commands to apply them to your cluster nothing in this repo should modify the local machine, require sudo, or make any changes to the local machine.

Helper scripts to automate installing CRC and required tools with versions used in openstack-k8s-operators can be found in [CRC/tools deployment](devsetup/README.md). These scripts/playbook required sudo permissions.

## Goals

1) WIP: Support installing individual operators for fast testing iteration

2) TODO: Support installing the combined Openstack umbrella operator

## Example using your preinstalled CRC (Code Ready Containers) Environment

Similar commands should work in any OCP environment though.
```bash
# set your CRC ENV variables and PATH for 'oc'
eval $(crc oc-env)

# one time operation to initialize PVs within the CRC VM
make crc_storage

# Install MariaDB Operator using OLM (defaults to quay.io/openstack-k8s-operators)
make mariadb MARIADB_IMG=quay.io/openstack-k8s-operators/mariadb-operator-index:latest

# Install Keystone Operator using OLM (defaults to quay.io/openstack-k8s-operators)
make keystone KEYSTONE_IMG=quay.io/openstack-k8s-operators/keystone-operator-index:latest
```

### Deploy example CRs
```bash
# Deploy MariaDB
make mariadb_deploy

# Deploy Keystone
make keystone_deploy
```

### Workflows
- [EDPM](docs/edpm.md)

## Deploy dev env using CRC, edpm nodes with isolated networks
* clone install_yamls
```bash
git clone https://github.com/openstack-k8s-operators/install_yamls.git
```

* install CRC
```bash
cd install_yamls/devsetup
CPUS=12 MEMORY=25600 DISK=100 make crc
```

* login to OCP
```bash
eval $(crc oc-env)
oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
```

* attach libvirt default network to the crc (default IP 192.168.122.10). This network is used as a vlan trunk to isolate the networks using vlans.
```bash
make crc_attach_default_interface
```

* create edpm node
```bash
EDPM_COMPUTE_SUFFIX=0 make edpm_compute
EDPM_COMPUTE_SUFFIX=1 make edpm_compute
EDPM_COMPUTE_SUFFIX=0 make edpm_compute_repos
EDPM_COMPUTE_SUFFIX=1 make edpm_compute_repos
```

* create dependencies
```bash
cd ..
make crc_storage
make input
```

* install opentack-operator
```bash
make openstack
```

**Note** this will also run the openstack_prep target, which if NETWORK_ISOLATION == true will install nmstate and metallb operator, configure the secondary interface of the crc VM via nncp, creates the network-attachment-definitions for internalapi, storage and tenant network. Also the metallb l2advertisement and the ipaddresspools get created.

The following NADs with ip ranges get configured:
```
internalapi: 172.17.0.30-172.17.0.70
storage:     172.18.0.30-172.18.0.70
tenant:      172.19.0.30-172.19.0.70
```

The following IPAddressPools with ip ranges get configured:
```
internalapi: 172.17.0.80-172.17.0.90
storage:     172.18.0.80-172.18.0.90
tenant:      172.19.0.80-172.19.0.90
```

* (optional) deploy ceph container using storage network
```bash
HOSTNETWORK=false NETWORKS_ANNOTATION=\'[\{\"name\":\"storage\",\"namespace\":\"openstack\"\}]\' MON_IP=172.18.0.30 make ceph TIMEOUT=90
```

**Note** as it is the first pod requesting an ip using the storage network, it will get the first IP from the configured range in the whereabouts ipam pool, which is 172.18.0.30 .

* deploy the ctlplane

If `NETWORK_ISOLATION == true`, `config/samples/core_v1beta1_openstackcontrolplane_network_isolation.yaml` will be used, if `false` then `config/samples/core_v1beta1_openstackcontrolplane.yaml`.

```bash
make openstack_deploy
```

(optional) To deploy with ceph as backend for glance and cinder, a sample config can be found at https://github.com/openstack-k8s-operators/openstack-operator/blob/master/config/samples/core_v1beta1_openstackcontrolplane_network_isolation_ceph.yaml .

**Note** Make sure to replace the `_FSID_` in the sample with the one from the ceph cluster. When deployed with `make ceph`

```bash
curl -o /tmp/core_v1beta1_openstackcontrolplane_network_isolation_ceph.yaml https://raw.githubusercontent.com/openstack-k8s-operators/openstack-operator/master/config/samples/core_v1beta1_openstackcontrolplane_network_isolation_ceph.yaml
FSID=$(oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' | base64 -d | grep fsid | sed -e 's/fsid = //') && echo $FSID
sed -i "s/_FSID_/${FSID}/" /tmp/core_v1beta1_openstackcontrolplane_network_isolation_ceph.yaml
oc apply -f /tmp/core_v1beta1_openstackcontrolplane_network_isolation_ceph.yaml
```

Wait for the ctlplane to be up.

At this point the ctlplane is deployed with the services using isolated networks as specified in the CR sample.

* need to restart nova-scheduler to pick up cell1, this is a known issue
oc delete pod -l service=nova-scheduler

* deploy edpm compute
```bash
make edpm_deploy
```

* wait until finished, then can check the env
```bash
oc rsh openstackclient
openstack compute service list
+--------------------------------------+----------------+------------------------+----------+---------+-------+----------------------------+
| ID                                   | Binary         | Host                   | Zone     | Status  | State | Updated At                 |
+--------------------------------------+----------------+------------------------+----------+---------+-------+----------------------------+
| 25ce958d-5c7b-47b8-a98a-8b84fb7e8790 | nova-conductor | nova-cell0-conductor-0 | internal | enabled | up    | 2023-03-06T15:29:09.000000 |
| 0ccc4465-f382-44db-8130-82503ad49a9a | nova-scheduler | nova-scheduler-0       | internal | enabled | up    | 2023-03-06T15:29:09.000000 |
| b64d6016-9c58-4657-8a4d-6fc5d73a4908 | nova-conductor | nova-cell1-conductor-0 | internal | enabled | up    | 2023-03-06T15:29:06.000000 |
| db60bfe7-be1a-4b8b-9939-5faf368ba96e | nova-compute   | edpm-compute-0         | nova     | enabled | up    | 2023-03-06T15:29:08.000000 |
+--------------------------------------+----------------+------------------------+----------+---------+-------+----------------------------+

openstack network agent list
+--------------------------------------+------------------------------+--------------------+-------------------+-------+-------+----------------------------+
| ID                                   | Agent Type                   | Host               | Availability Zone | Alive | State | Binary                     |
+--------------------------------------+------------------------------+--------------------+-------------------+-------+-------+----------------------------+
| 03cec1ed-c20f-4f3e-9786-ad9c9b3f8937 | OVN Controller agent         | crc-9ltqk-master-0 |                   | :-)   | UP    | ovn-controller             |
| 5d0fd2b2-e8e8-478b-b8ad-26fa5692afcd | OVN Controller Gateway agent | edpm-compute-0     |                   | :-)   | UP    | ovn-controller             |
| e20a1b5d-990e-57cc-838d-ffe34b27bef9 | OVN Metadata agent           | edpm-compute-0     |                   | :-)   | UP    | neutron-ovn-metadata-agent |
+--------------------------------------+------------------------------+--------------------+-------------------+-------+-------+----------------------------+
```

## Simple steps to validate the deployment

Inside the openstackclient pod run

* create image
```bash
curl -L -o /tmp/cirros.img http://download.cirros-cloud.net/0.5.2/cirros-0.5.2-x86_64-disk.img
qemu-img convert -O raw /tmp/cirros.img /tmp/cirros.raw
openstack image create --container-format bare --disk-format raw --file /tmp/cirros.raw cirros
```

* create networks
```bash
openstack network create private --share
openstack subnet create priv_sub --subnet-range 192.168.0.0/24 --network private
openstack network create public --external  --provider-network-type flat --provider-physical-network datacentre
openstack subnet create pub_sub --subnet-range 192.168.122.0/24 --allocation-pool start=192.168.122.200,end=192.168.122.210 --gateway 192.168.122.1 --no-dhcp --network public
openstack router create priv_router
openstack router add subnet priv_router priv_sub
openstack router set priv_router --external-gateway public
```

* create flavor
```bash
openstack flavor create --ram 512 --vcpus 1 --disk 1 --ephemeral 1 m1.small
```

*create an instance
```bash
openstack server create --flavor m1.small --image cirros --nic net-id=private test
openstack floating ip create public --floating-ip-address 192.168.122.20
openstack server add floating ip test 192.168.122.20
openstack server list
+--------------------------------------+------+--------+---------------------------------------+--------+----------+
| ID                                   | Name | Status | Networks                              | Image  | Flavor   |
+--------------------------------------+------+--------+---------------------------------------+--------+----------+
| a45e1674-cc72-4b19-b852-2d0d44f2e9c9 | test | ACTIVE | private=192.168.0.77, 192.168.122.20  | cirros | m1.small |
+--------------------------------------+------+--------+---------------------------------------+--------+----------+

openstack security group rule create --protocol icmp --ingress --icmp-type -1 $(openstack security group list --project admin -f value -c ID)
openstack security group rule create --protocol tcp --ingress --dst-port 22 $(openstack security group list --project admin -f value -c ID)

# check connectivity via FIP
ping -c4 192.168.122.20

```
