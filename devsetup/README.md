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

Deploy additional VM's for compute nodes:
```
# Creates edpm-compute-0:
make edpm_compute
# Set $EDPM_COMPUTE_SUFFIX to create additional VM's beyond 0:
make edpm_compute EDPM_COMPUTE_SUFFIX=1
```

Edit edpm/edpm-play.yaml and set the compute node VM IP addresses in the
inventory. The IP address in the inventory (192.168.122.139) needs to be
changed to the right IP for edpm-compute-0 in the environment. The
edpm-compute-0 IP can be discovered with the following command:
```
sudo virsh net-dhcp-leases default
```

Execute the ansible to configure the compute nodes:
```
make edpm-play
```

Cleanup:
```
make edpm_play_cleanup
# Will delete VM's!:
make edpm_compute_cleanup
make edpm_compute_cleanup EDPM_COMPUTE_SUFFIX=1
```
