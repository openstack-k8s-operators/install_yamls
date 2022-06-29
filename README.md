# k8s yaml generator/installer for Cloud Native OpenStack

The main purpose is to provide scripts to automate installing OpenStack in your *pre-installed* OpenShift environment.

Aside from generating Yaml and running *oc* commands to apply them to your cluster nothing in this repo should modify the local machine, require sudo, or make any changes to the local machine.

Helper scripts to automate installing CRC and required tools with versions used in openstack-k8s-operators can be found in [CRC/tools deployment](devsetup/README.md). These scripts/playbook required sudo permissions.

## Goals

1) WIP: Support installing individual operators for fast testing iteration

2) TODO: Support installing the combined Openstack umbrella operator

### Example using your preinstalled CRC (Code Ready Containers) Environment
### Similar commands should work in any OCP environment though.
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
