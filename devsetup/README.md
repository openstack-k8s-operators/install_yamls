# CRC automation + tool deployment
### CRC
CRC installation requires sudo to create a NetworkManager dispatcher file in /etc/NetworkManager/dispatcher.d/99-crc.sh, also the post step to add the CRC cert to the system store to be able to access the image registry from the host system.

* Get the pull secret from `https://cloud.redhat.com/openshift/create/local` and save it in `pull-secret.txt` of the repo dir, or set the `PULL_SECRET` env var to point to a different location.
* `CRC_URL` and `KUBEADMIN_PWD` can be used to change requirements for CRC install

```bash
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

# show kubeadmin and devel login detains
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


### tool deployment
All tools and specific version to develop operators for this Cloud Native OpenStack approch can be deployed via the download_tools make target. All components which don't get installed via rpm get installed to $HOME/bin or /usr/local/bin (go/gofmt).

```bash
make download_tools
```
