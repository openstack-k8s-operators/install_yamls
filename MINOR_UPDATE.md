# Minor Update Development and Testing

This readme outlines the procedures for developing and testing openstack minor update workflow.
You can either run the complete end-to-end update process or focus on specific parts of it.

## Applying a minor update end-to-end on already deployed environment

First, ensure you have a complete environment deployed by following the instructions in the [main](README.md) file.

Execute the end-to-end update procedure by running the following command:
```
make openstack_update_run
```

## Deploying new environment from scratch to prepare for minor update run
Complete crc setup and tools deployment explained [here](devsetup/README.md)

Next run those steps to prepare crc VM with local-storage configured and two edpm
computes deployed alongside the crc VM:

```
cd install_yamls/devsetup
CPUS=12 MEMORY=25600 DISK=100 make crc
eval $(crc oc-env)
oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
make crc_attach_default_interface
EDPM_TOTAL_NODES=2 make edpm_compute
cd ..
make crc_storage
```

Next run:

```
make openstack_update_prep
```

After openstack_update_prep completes new `AVAILABLE VERSION` in openstackversion CR should appear:

```bash
oc get openstackversion
NAME                                 TARGET VERSION     AVAILABLE VERSION   DEPLOYED VERSION
openstack-galera-network-isolation   0.3.0-1749195356   0.0.2               0.3.0-1749195356
```

## Patch openstack version to start minor update run

Patches the openstackversion CR target version to the available version, if there is an update available.
New `AVAILABLE VERSION` should b already available, otherwise the make target will timeout.

```
make openstack_patch_version
```

This starts OVN update on control plane and wait for creation of the OpenStackDataPlaneDeployment to update OVN on the EDPM nodes.
