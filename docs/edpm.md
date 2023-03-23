# EDPM

Deploying EDPM with network isolation

### Dev setup
Setting the node(s)
```shell
cd devsetup
make crc
make crc_attach_default_interface
EDPM_COMPUTE_SUFFIX=0 make edpm_compute
EDPM_COMPUTE_SUFFIX=0 make edpm_compute_repos
EDPM_COMPUTE_SUFFIX=1 make edpm_compute
EDPM_COMPUTE_SUFFIX=1 make edpm_compute_repos

# check that the two computes got and IP suffix of 100 and 101 respectively as the later steps depends on that

cd ..
```
### Deploy
```shell
make crc_storage
TIMEOUT=90 HOSTNETWORK=false NETWORKS_ANNOTATION=\'[\{\"name\":\"storage\",\"namespace\":\"openstack\"\}]\' MON_IP=172.18.0.30 make ceph # (optional)
make openstack # it will deploy the network isolation operators by default now (for disabling set NETWORK_ISOLATION=false)
make openstack_deploy # it will use the network isolation sample by default now (for disabling set NETWORK_ISOLATION=false)
oc delete pod -l service=nova-scheduler  # we need to restart nova-scheduler to pick up cell1, this is a known issue
DATAPLANE_SINGLE_NODE=false make edpm_deploy # it will deploy 2 nodes
```

### Ansible Logs
```shell
# you can follow the ansible logs with
while true; do oc logs -f `oc get pods | grep dataplane-deployment | grep Running| cut -d ' ' -f1` || echo -n .; sleep 1; done
```
