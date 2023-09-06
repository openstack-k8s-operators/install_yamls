# k8s yaml generator/installer for Cloud Native OpenStack

The main purpose is to provide scripts to automate installing OpenStack in your *pre-installed* OpenShift environment.

Aside from generating Yaml and running *oc* commands to apply them to your cluster nothing in this repo should modify the local machine, require sudo, or make any changes to the local machine.

Helper scripts to automate installing CRC and required tools with versions used in openstack-k8s-operators can be found in [devsetup](devsetup/README.md). These scripts/playbook required sudo permissions.

**Note**
The `install_yamls` project expects several dependencies on the host machine.
Without them the deployment will fail and you will have install them first.
In general terms, all tools required by Openshift are also required by `install_yamls`.
Most importanly, the `kubectl` must be present on the system.

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

(optional) To deploy with ceph as backend for glance and cinder, a sample config can be found at https://github.com/openstack-k8s-operators/openstack-operator/blob/main/config/samples/core_v1beta1_openstackcontrolplane_network_isolation_ceph.yaml .

**Note** Make sure to replace the `_FSID_` in the sample with the one from the ceph cluster. When deployed with `make ceph`

```bash
curl -o /tmp/core_v1beta1_openstackcontrolplane_network_isolation_ceph.yaml https://raw.githubusercontent.com/openstack-k8s-operators/openstack-operator/main/config/samples/core_v1beta1_openstackcontrolplane_network_isolation_ceph.yaml
FSID=$(oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' | base64 -d | grep fsid | sed -e 's/fsid = //') && echo $FSID
sed -i "s/_FSID_/${FSID}/" /tmp/core_v1beta1_openstackcontrolplane_network_isolation_ceph.yaml
oc apply -f /tmp/core_v1beta1_openstackcontrolplane_network_isolation_ceph.yaml
```

Wait for the ctlplane to be up.

At this point the ctlplane is deployed with the services using isolated networks as specified in the CR sample.

* need to restart nova-scheduler to pick up cell1, this is a known issue
```bash
oc delete pod -l service=nova-scheduler
```

* deploy edpm compute
```bash
# To use a NTP server other than the ntp.pool.org default one, override the DATAPLANE_CHRONY_NTP_SERVER variable
make edpm_deploy
```

* wait until finished, then can check the env
```bash
oc rsh openstackclient
openstack compute service list
+--------------------------------------+----------------+------------------------+----------+---------+-------+----------------------------+
| ID                                   | Binary         | Host                   | Zone     | Status  | State | Updated At                 |
+--------------------------------------+----------------+------------------------+----------+---------+-------+----------------------------+
| f464521e-19d0-4b2d-9cdb-92aa17c677c9 | nova-conductor | nova-cell0-conductor-0 | internal | enabled | up    | 2023-04-11T17:36:27.000000 |
| bdec6195-e9e0-463c-a64a-0ab0bc5238af | nova-scheduler | nova-scheduler-0       | internal | enabled | up    | 2023-04-11T17:36:19.000000 |
| e8a6d8d1-8a56-490c-8adb-19ec8b1fb8c9 | nova-conductor | nova-cell1-conductor-0 | internal | enabled | up    | 2023-04-11T17:36:27.000000 |
| 2833213e-7ba7-4fc2-a5b6-3467f04368e4 | nova-compute   | edpm-compute-1         | nova     | enabled | up    | 2023-04-11T17:36:23.000000 |
| bafb827c-6380-408d-afea-2cc2167b3916 | nova-compute   | edpm-compute-0         | nova     | enabled | up    | 2023-04-11T17:36:23.000000 |
+--------------------------------------+----------------+------------------------+----------+---------+-------+----------------------------+

openstack network agent list
+--------------------------------------+------------------------------+--------------------+-------------------+-------+-------+----------------------------+
| ID                                   | Agent Type                   | Host               | Availability Zone | Alive | State | Binary                     |
+--------------------------------------+------------------------------+--------------------+-------------------+-------+-------+----------------------------+
| 74bdefce-79df-4d0a-8bb4-1fe7cb6b0af5 | OVN Controller agent         | crc-9ltqk-master-0 |                   | :-)   | UP    | ovn-controller             |
| b319f055-d7da-4fb3-92f2-ea30e82b7452 | OVN Controller Gateway agent | edpm-compute-0     |                   | :-)   | UP    | ovn-controller             |
| 2fe19901-a7ee-4820-a43f-f5d32a303165 | OVN Controller Gateway agent | edpm-compute-1     |                   | :-)   | UP    | ovn-controller             |
| 24ac30d9-35ce-5c0e-a6b1-7cb098c4ecbf | OVN Metadata agent           | edpm-compute-1     |                   | :-)   | UP    | neutron-ovn-metadata-agent |
| 9d5bdc6f-225e-5309-8e82-c43b839996cc | OVN Metadata agent           | edpm-compute-0     |                   | :-)   | UP    | neutron-ovn-metadata-agent |
+--------------------------------------+------------------------------+--------------------+-------------------+-------+-------+----------------------------+
```

## Simple steps to validate the deployment

```
cd devsetup
make edpm_deploy_instance
```
