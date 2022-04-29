# k8s yaml generator/installer for Cloud Native OpenStack

Scripts to automate Installing OpenStack in your *pre-installed* OpenShift environment.

Aside from generating Yaml and running *oc* commands to apply them to your cluster nothing in this repo should modify the local machine, require sudo, or make any changes to the local environment.

## Goals

1) WIP: Support installing individual operators for fast testing iteration

2) TODO: Support installing the combined Openstack umbrella operator

### Example using your preinstalled CRC (Code Ready Containers) Environment
### Similar commands should work in any OCP environment though.
```bash
# set your CRC ENV variables and PATH for 'oc'
eval $(crc oc-env)

# one time operation to initialize PVs within the CRC VM
make crc_init

# Install MariaDB Operator using OLM (defaults to quay.io/openstack-k8s-operators)
make mariadb MARIADB_IMG=quay.io/openstack-k8s-operators/mariadb-operator-index:latest

# Install Keystone Operator using OLM (defaults to quay.io/openstack-k8s-operators)
make keystone KEYSTONE_IMG=quay.io/openstack-k8s-operators/keystone-operator-index:latest

```

