# OCP automation + tool deployment
### OCP installation

### CRC
CRC installation requires sudo to create a NetworkManager dispatcher file in /etc/NetworkManager/dispatcher.d/99-crc.sh, also the post step to add the CRC cert to the system store to be able to access the image registry from the host system.

* Get the pull secret from `https://cloud.redhat.com/openshift/create/local` and save it in `pull-secret.txt` of the repo dir, or set the `PULL_SECRET` env var to point to a different location.
* `CRC_URL` and `KUBEADMIN_PWD` can be used to change requirements for CRC install. The default `KUBEADMIN_PWD` is `12345678`

```bash
cd <install_yamls_root_path>/devsetup
CPUS=12 MEMORY=25600 DISK=100 make crc
```

**Note**
To configure a http and/or https proxy on the crc instance, use `CRC_HTTP_PROXY` and `CRC_HTTPS_PROXY`.

After the installation is complete, proceed with the OpenStack service provisioning.


### SNO
Single-node-Openshift can also be installed in a configuration which is similar to CRC it takes longer to install but the resulting OCP better represents what end-users are running

* Get the pull secret from `https://cloud.redhat.com/openshift/create/local` and save it in `pull-secret.txt` of the repo dir, or set the `PULL_SECRET` env var to point to a different location.
* `SNO_OCP_VERSION` can be used to change requirements for the SNO install.

```bash
cd <install_yamls_root_path>/devsetup
CPUS=12 MEMORY=25600 DISK=100 make sno
```

### Access OCP from external systems

On the local system add the required entries to your local /etc/hosts. The previous used ansible playbook also outputs the information for CRC:

```
cat <<EOF >> /etc/hosts
192.168.130.11 api.crc.testing canary-openshift-ingress-canary.apps-crc.testing console-openshift-console.apps-crc.testing default-route-openshift-image-registry.apps-crc.testing downloads-openshift-console.apps-crc.testing oauth-openshift.apps-crc.testing
EOF
```

and for SNO:
```
cat <<EOF >> /etc/hosts
192.168.130.11 api.sno.lab.example.com canary-openshift-ingress-canary.apps.sno.lab.example.com console-openshift-console.apps.sno.lab.example.com default-route-openshift-image-registry.apps.sno.lab.example.com downloads-openshift-console.apps.sno.lab.example.com oauth-openshift.apps.sno.lab.example.com
EOF
```

**Note**
validate that the IP address matches the installed OCP VM.

To access OCP console

On the local system, enable SSH proxying:
```
# on Fedora
sudo dnf install sshuttle

# on RHEL
sudo pip install sshuttle

sshuttle -r <user>@<virthost> 192.168.130.0/24
```

Now you can access the OCP environment
* console using the local web browser: <https://console-openshift-console.apps-crc.testing>
* `oc` client: `oc login -u kubeadmin -p ${KUBEADMIN_PWD} https://api.crc.testing:6443`

### tool deployment
All tools and specific version to develop operators for this Cloud Native OpenStack approch can be deployed via the download_tools make target. All components which don't get installed via rpm get installed to $HOME/bin or /usr/local/bin (go/gofmt).

```bash
cd <install_yamls_root_path>/devsetup
make download_tools
```

### EDPM deployment
The EDPM deployment will create additional VM's alongside the crc VM, provides
a mechanism to configure them using the ansibleee-operator.

After completing the devsetup, attach the crc VM to the default network:
```
make attach_default_interface
```

This requires running operators required for controlplane and dataplane:
```
pushd ..
make openstack
make openstack_init
popd
```

This requires controlplane to be deployed before dataplane:
```
pushd ..
make openstack_deploy
popd
```

Deploy a compute node VM:
```
# Creates edpm-compute-0:
make edpm_compute
```

You can deploy a compute node VM with additional devices:
```
EDPM_EMULATED_NVME_ENABLED=true \
EDPM_EMULATED_SRIOV_NIC_ENABLED=true \
make edpm_compute
```

Execute the edpm_deploy step:
```
pushd ..
make edpm_deploy
popd
```

You can also deploy additional compute node VMs:
```
# Set $EDPM_COMPUTE_SUFFIX to create additional VM's beyond 0:
make edpm_compute EDPM_COMPUTE_SUFFIX=1
```
The IP of the compute node will be statically assigned starting at
192.168.122.100 (based on the default EDPM_COMPUTE_SUFFIX=0).

Then edit inventory in edpm/edpm-play.yaml.

Cleanup:
```
pushd ..
make edpm_deploy_cleanup
popd

# Will delete VM's!:
make edpm_compute_cleanup
```

In case additional compute node VMs are deployed, run:
```
make edpm_compute_cleanup EDPM_COMPUTE_SUFFIX=1
```

### EDPM virtual baremetal deployment

The EDPM virtual machines can be managed by the openstack-baremetal-operator and
metal3, which interact with a virtual Redfish BMC provided by sushy-tools.

This requires running operators required for controlplane and dataplane:
```
pushd ..
make openstack
popd
```

This requires controlplane to be deployed before dataplane:
```
pushd ..
make openstack_deploy
make openstack_init
popd
```

Create and manage the virtual machines:
```
BM_NODE_COUNT=1 make edpm_baremetal_compute

# optional, create more virtual machines later:
# creates edpm-baremetal-compute-01 and edpm-baremetal-compute-02
BM_NODE_COUNT=2 BM_NODE_SUFFIX=1 make edpm_baremetal_compute

# optional, create more virtual machines with differet names:
# creates edpm-bootc-00
BM_NODE_PREFIX=edpm-bootc make edpm_baremetal_compute
```

The dataplane can then be deployed on these nodes as for other baremetal
dataplane deployments:
```
pushd ..
DATAPLANE_TOTAL_NODES=1 make edpm_deploy_baremetal
popd
```

Cleanup:
```
pushd ..
make edpm_deploy_cleanup
popd
# Will delete VM's!:
BM_NODE_COUNT=1 make edpm_baremetal_compute_cleanup

# optional, cleanup other virtual machines:
# cleans up edpm-baremetal-compute-01 and edpm-baremetal-compute-02
BM_NODE_COUNT=2 BM_NODE_SUFFIX=1 make edpm_baremetal_compute_cleanup

# optional, cleanup virtual machines with differet names:
# cleans up edpm-bootc-00
BM_NODE_PREFIX=edpm-bootc make edpm_baremetal_compute_cleanup
```

### BMaaS LAB
The BMaaS LAB will create additional VM's alongside the CRC instance as well
as a virtual RedFish (sushy-emulator) service running in CRC. The VMs can be
used as virtual baremetal nodes managed by Ironic deployed on CRC.

The VM's are attached to a separate libvirt network `crc-bmaas`, this network
is attached to the CRC instance and a linux-bridge, `crc-bmaas`, is
configured on the CRC with a NetworkAttachmentDefinition `baremetal`.

When deploying ironic, set up the `networkAttachments`, `provisionNetwork` and
`inspectionNetwork` to use the `baremetal` NetworkAttachmentDefinition.

The MetalLB load-balancer is also configured with an address pool and L2
advertisment for the `baremetal` network.

The 172.20.1.0/24 subnet is split into pools as shown in the table below.
| Address pool      | Reservation                                      |
| :---------------- | :----------------------------------------------- |
| `172.20.1.1/32`   | Router address                                   |
| `172.20.1.2/32`   | CRC bridge (`crc-bmaas`) address                 |
| `172.20.1.0/26`   | Whearabouts IPAM (addresses for pods)            |
| `172.20.1.64/26`  | MetalLB IPAddressPool                            |
| `172.20.1.128/25` | Available for ironic provisioning and inspection |


Example:
```yaml
  ---
  apiVersion: ironic.openstack.org/v1beta1
  kind: Ironic
  metadata:
    name: ironic
    namespace: openstack
  spec:
    < --- snip --->
    ironicConductors:
    - networkAttachments:
      - baremetal
      provisionNetwork: baremetal
      dhcpRanges:
      - name: netA
        cidr: 172.20.1.0/24
        start: 172.20.1.130
        end: 172.20.1.200
        gateway: 172.20.1.1
    ironicInspector:
      networkAttachments:
      - baremetal
      inspectionNetwork: baremetal
      dhcpRanges:
      - name: netA
        cidr: 172.20.1.0/24
        start: 172.20.1.201
        end: 172.20.1.220
        gateway: 172.20.1.1
    < --- snip --->
```

The RedFish (sushy-emulator) is accessible via a route:
http://sushy-emulator.apps-crc.testing

```commandline
curl -u admin:password http://sushy-emulator.apps-crc.testing/redfish/v1/Systems/
```
```json
{
    "@odata.type": "#ComputerSystemCollection.ComputerSystemCollection",
    "Name": "Computer System Collection",
    "Members@odata.count": 2,
    "Members": [

            {
                "@odata.id": "/redfish/v1/Systems/e5b1b096-f585-4f39-9174-e03bffe46a95"
            },

            {
                "@odata.id": "/redfish/v1/Systems/f91de773-c6a4-4a1b-b419-e0b3dbda3b84"
            }

    ],
    "@odata.context": "/redfish/v1/$metadata#ComputerSystemCollection.ComputerSystemCollection",
    "@odata.id": "/redfish/v1/Systems",
    "@Redfish.Copyright": "Copyright 2014-2016 Distributed Management Task Force, Inc. (DMTF). For the full DMTF copyright policy, see http://www.dmtf.org/about/policies/copyright."
```

#### Pre-requisites
Install CRC and the nmstate operator and the openstack namespace
```commandline
cd <install_yamls_root_path>/devsetup
make crc
cd <install_yamls_root_path>/
make nmstate
make namespace
```

#### Create the BMaaS LAB
```commandline
cd <install_yamls_root_path>/devsetup
make bmaas BMAAS_NODE_COUNT=4  # Default node count is: 1
```

#### Cleanup
```commandline
cd <install_yamls_root_path>/devsetup
make bmaas_cleanup
```

#### Enroll nodes using node inventory yaml

**TIP** `make bmaas_generate_nodes_yaml | tail -n +2` will print nodes YAML

Example:
```yaml
---
nodes:
- name: crc-bmaas-01
  driver: redfish
  driver_info:
    redfish_address: http://sushy-emulator.apps-crc.testing
    redfish_system_id: /redfish/v1/Systems/f91de773-c6a4-4a1b-b419-e0b3dbda3b84
    redfish_username: admin
    redfish_password: password
  ports:
  - address: 52:54:00:fa:a7:b1
- name: crc-bmaas-02
  driver: redfish
  driver_info:
    redfish_address: http://sushy-emulator.apps-crc.testing
    redfish_system_id: /redfish/v1/Systems/e5b1b096-f585-4f39-9174-e03bffe46a95
    redfish_username: admin
    redfish_password: password
  ports:
  - address: 52:54:00:8a:ea:14
```

### IPv6 LAB

#### Create the IPv6 LAB

Export vars:
```bash
export NETWORK_ISOLATION_NET_NAME=net-iso
export NETWORK_ISOLATION_IPV4=false
export NETWORK_ISOLATION_IPV6=true
export NETWORK_ISOLATION_INSTANCE_NAME=sno
export NETWORK_ISOLATION_IP_ADDRESS=fd00:aaaa::10
export NNCP_INTERFACE=enp7s0
```

Change to the devsetup directory:
```bash
cd <install_yamls_root_path>/devsetup
```

Set up the networking using NAT64 and SNO Single-node-Openshift:
```bash
make ipv6_lab
```

Create the network-isolation network with IPv6 enabled
```bash
make network_isolation_bridge
```

Attach the network-isolation bridge to SNO (Single-node-Openshift):
```bash
make attach_default_interface
```

Login to the cluster:
```bash
oc login -u admin -p 12345678 https://api.sno.lab.example.com:6443
```
