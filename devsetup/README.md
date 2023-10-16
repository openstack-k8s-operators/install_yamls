# CRC automation + tool deployment
### CRC
CRC installation requires sudo to create a NetworkManager dispatcher file in /etc/NetworkManager/dispatcher.d/99-crc.sh, also the post step to add the CRC cert to the system store to be able to access the image registry from the host system.

* Get the pull secret from `https://cloud.redhat.com/openshift/create/local` and save it in `pull-secret.txt` of the repo dir, or set the `PULL_SECRET` env var to point to a different location.
* `CRC_URL` and `KUBEADMIN_PWD` can be used to change requirements for CRC install. The default `KUBEADMIN_PWD` is `12345678`

```bash
cd <install_yamls_root_path>/devsetup
make crc
```

After the installation is complete, proceed with the OpenStack service provisioning.

The steps it runs are the following:
```bash
# Pre req
# verifies that the pull secret is located at $(pwd)/pull-secret.txt (get it from https://cloud.redhat.com/openshift/create/local)

* install crc
mkdir -p ~/bin
curl -L https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz | tar -U --strip-components=1 -C ~/bin -xJf - crc

# config CRC
crc config set consent-telemetry no
crc config set kubeadmin-password ${KUBEADMIN_PWD}
crc config set pull-secret-file ${PULL_SECRET_FILE}
crc setup

crc start

# show kubeadmin and devel login details
crc console --credentials

# add crc provided oc client to PATH
eval $(${CRC_BIN} oc-env)

# login to crc env
oc login -u kubeadmin -p ${KUBEADMIN_PWD} https://api.crc.testing:6443

# make sure you can push to the internal registry; without this step you'll get x509 errors
echo -n "Adding router-ca to system certs to allow accessing the crc image registry"
oc extract secret/router-ca --keys=tls.crt -n openshift-ingress-operator --confirm
sudo cp -f tls.crt /etc/pki/ca-trust/source/anchors/crc-router-ca.pem
sudo update-ca-trust
```

#### Access OCP from external systems

On the local system add the required entries to your local /etc/hosts. The previous used ansible playbook also outputs the information:

```
cat <<EOF >> /etc/hosts
192.168.130.11 api.crc.testing canary-openshift-ingress-canary.apps-crc.testing console-openshift-console.apps-crc.testing default-route-openshift-image-registry.apps-crc.testing downloads-openshift-console.apps-crc.testing oauth-openshift.apps-crc.testing
EOF
```

**Note**
validate that the IP address matches the installed CRC VM.

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
make crc_attach_default_interface
```

Deploy a compute node VM:
```
# Creates edpm-compute-0:
make edpm_compute
```

Execute the edpm_deploy step:
```
cd ..
make edpm_deploy
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
make edpm_play_cleanup
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

This requires a running baremetal-operator, and dataplane-operator:
```
pushd ..
make openstack
popd
```

Create and manage the virtual machines:
```
BM_NODE_COUNT=1 make edpm_baremetal_compute
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
        start: 172.20.1.100
        end: 172.20.1.150
        gateway: 172.20.1.1
    ironicInspector:
      networkAttachments:
      - baremetal
      inspectionNetwork: baremetal
      dhcpRanges:
      - name: netA
        cidr: 172.20.1.0/24
        start: 172.20.1.70
        end: 172.20.1.90
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
