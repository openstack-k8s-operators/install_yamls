#!/bin/bash
#
# Copyright 2022 Red Hat Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

set -e

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit 1
fi

function usage {
    echo
    echo "options:"
    echo "  --create        Create OCP Single-Node instance lab"
    echo "  --cleanup       Destroy OCP Single-Node instance lab"
    echo
}

function install_dependencies {
    local dependencies
    dependencies=""
    if ! rpm --quiet -q --whatprovides httpd-tools; then
        dependencies="$dependencies httpd-tools"
    fi
    if ! rpm --quiet -q --whatprovides virt-install; then
        dependencies="$dependencies virt-install"
    fi
    if [ -n "$dependencies" ]; then
        sudo dnf -y install "$dependencies" || { echo "Unable to install dependencies: $dependencies"; exit 1; }
    fi
}

MY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${MY_TMP_DIR}"' EXIT

WORK_DIR="${WORK_DIR:-$HOME/.sno-workdir}"

# OCP installer
PULL_SECRET="${PULL_SECRET:-${HOME}/pull-secret.txt}"
SSH_PUB_KEY="${SSH_PUB_KEY:-${HOME}/.ssh/id_rsa.pub}"
OCP_VERSION="${OCP_VERSION:-latest-4.14}"
OCP_MIRROR_URL="${OCP_MIRROR_URL:-https://mirror.openshift.com/pub/openshift-v4/clients/ocp}"
OCP_ADMIN_PASSWD=${OCP_ADMIN_PASSWD:-12345678}
BOOTSTRAP_ISO_FILENAME="${BOOTSTRAP_ISO_FILENAME:-rhcos-live-with-ignition.iso}"

# Networking
NETWORK_NAME="${NETWORK_NAME:-nat64}"
NAT64_IPV6_DNSMASQ_VAR_DIR=${NAT64_IPV6_DNSMASQ_VAR_DIR:-/var/lib/dnsmasq/${NETWORK_NAME}-v6}
NAT64_IPV6_DNSMASQ_SERVICE_NAME=${NAT64_IPV6_DNSMASQ_SERVICE_NAME:-${NETWORK_NAME}-v6-dnsmasq.service}
NAT64_IPV6_DNSMASQ_CONF_DIR=${NAT64_IPV6_DNSMASQ_CONF_DIR:-/etc/${NETWORK_NAME}-v6-dnsmasq}

SNO_CLUSTER_NETWORK=${SNO_CLUSTER_NETWORK:-fd00:abcd:0::/48}
SNO_HOST_PREFIX=${SNO_HOST_PREFIX:-64}
SNO_MACHINE_NETWORK=${SNO_MACHINE_NETWORK:-fd00:abcd:abcd:fc00::/64}
SNO_SERVICE_NETWORK=${SNO_SERVICE_NETWORK:-fd00:abcd:abcd:fc03::/112}
SNO_HOST_IP=${SNO_HOST_IP:-fd00:abcd:abcd:fc00::11}
SNO_HOST_MAC="${SNO_HOST_MAC:-$(echo -n 52:54:00; dd bs=1 count=3 if=/dev/random 2>/dev/null | hexdump -v -e '/1 "-%02X"' | tr '-' ':')}"

# VM config
SNO_INSTANCE_NAME="${SNO_INSTANCE_NAME:-sno}"
ARCH="${ARCH:-x86_64}"
MEMORY="${MEMORY:-32768}"
VCPUS="${VCPUS:-12}"
OS_VARIANT="${OS_VARIANT:-fedora-coreos-stable}"
DISK_SIZE="${DISK_SIZE:-150}"
VIRT_TYPE="${VIRT_TYPE:-kvm}"
NET_MODEL="${NET_MODEL:-virtio}"
# Libvirt config
LIBVIRT_URL="${LIBVIRT_URL:-"qemu:///system"}"
VIRSH_CMD="virsh --connect=$LIBVIRT_URL"
LIBVIRT_STORAGE_POOL=${LIBVIRT_STORAGE_POOL:-default}

if ! [ -f "${PULL_SECRET}" ]; then
    echo "ERROR: PULL_SECRET - ${PULL_SECRET} no such file"
    exit 1
fi
if ! [ -f "${SSH_PUB_KEY}" ]; then
    echo "ERROR: SSH_PUB_KEY - ${SSH_PUB_KEY} no such file"
    exit 1
fi

mkdir -p "${WORK_DIR}"/ocp
mkdir -p "${WORK_DIR}"/bin
sudo chcon -t bin_t ${WORK_DIR}/bin

function get_oc_client {
    pushd ${WORK_DIR}

    # Download the OpenShift Container Platform client (oc)
    if ! [ -f oc.tar.gz ]; then
        curl ${OCP_MIRROR_URL}/$OCP_VERSION/openshift-client-linux.tar.gz \
            -o oc.tar.gz
    fi
    tar zxf oc.tar.gz -C ./bin/
    chmod +x ./bin/oc

    popd
}

function get_openshift_installer {
    pushd ${WORK_DIR}

    # Download the OpenShift Container Platform installer
    if ! [ -f openshift-install-linux.tar.gz ]; then
        curl -k \
            "${OCP_MIRROR_URL}"/"$OCP_VERSION"/openshift-install-linux.tar.gz \
            -o openshift-install-linux.tar.gz
    fi
    tar zxf openshift-install-linux.tar.gz -C ./bin/
    chmod +x ./bin/openshift-install

    popd
}

function get_rhcos_live_iso {
    pushd ${WORK_DIR}

    if ! [ -f rhcos-live.iso ]; then
        # Retrieve the RHCOS ISO URL
        ISO_URL=$(./bin/openshift-install coreos print-stream-json | grep location | grep ${ARCH} | grep iso | cut -d\" -f4)

        # Download the RHCOS ISO
        curl -L ${ISO_URL} -o rhcos-live.iso
    fi

    popd
}

function create_install_iso {
    pushd ${WORK_DIR}

    # intall-config.yaml
    cat << EOF > ./ocp/install-config.yaml
apiVersion: v1
baseDomain: lab.example.com
compute:
- name: worker
  replicas: 0
controlPlane:
  name: master
  replicas: 1
metadata:
  name: sno
networking:
  clusterNetwork:
  - cidr: ${SNO_CLUSTER_NETWORK}
    hostPrefix: ${SNO_HOST_PREFIX}
  machineNetwork:
  - cidr: ${SNO_MACHINE_NETWORK}
  networkType: OVNKubernetes
  serviceNetwork:
  - ${SNO_SERVICE_NETWORK}
platform:
  none: {}
bootstrapInPlace:
  installationDisk: /dev/vda
pullSecret: |
  $(cat ${PULL_SECRET})
sshKey: |
  $(cat ${SSH_PUB_KEY})
EOF


    ./bin/openshift-install --dir=./ocp create single-node-ignition-config

    cp -v rhcos-live.iso ${BOOTSTRAP_ISO_FILENAME}
    podman run --privileged --pull always --rm \
        -v /dev:/dev -v /run/udev:/run/udev -v "$PWD":/data \
        -w /data quay.io/coreos/coreos-installer:release \
        iso ignition embed -fi ./ocp/bootstrap-in-place-for-live-iso.ign \
        ${BOOTSTRAP_ISO_FILENAME}
    echo "Bootstrap iso ${BOOTSTRAP_ISO_FILENAME} created"
    size=$(stat -Lc%s ${BOOTSTRAP_ISO_FILENAME})
    sudo virsh vol-create-as ${LIBVIRT_STORAGE_POOL} ${BOOTSTRAP_ISO_FILENAME} ${size} --format raw
    sudo virsh vol-upload --pool ${LIBVIRT_STORAGE_POOL} ${BOOTSTRAP_ISO_FILENAME} ${BOOTSTRAP_ISO_FILENAME}

    popd
}

function create_sno_instance {
    virt-install --connect ${LIBVIRT_URL} \
        --name ${SNO_INSTANCE_NAME} \
        --memory ${MEMORY} \
        --vcpus ${VCPUS} \
        --boot uefi,hd,cdrom,bootmenu.enable=yes,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no \
        --os-variant ${OS_VARIANT} \
        --disk size=${DISK_SIZE} \
        --disk readonly=yes,device=cdrom,vol=${LIBVIRT_STORAGE_POOL}/${BOOTSTRAP_ISO_FILENAME} \
        --network network=${NETWORK_NAME},mac.address=${SNO_HOST_MAC},model=${NET_MODEL} \
        --noautoconsole \
        --virt-type ${VIRT_TYPE} \
        --import \
        --events on_crash=restart
    echo "OCP single-node instance ${SNO_INSTANCE_NAME} created"
}

function destroy_sno_instance {
    if ${VIRSH_CMD} list --all --name | grep --silent "^${SNO_INSTANCE_NAME}\$"; then
        ${VIRSH_CMD} destroy "${SNO_INSTANCE_NAME}" || true
        ${VIRSH_CMD} undefine "${SNO_INSTANCE_NAME}" --nvram --remove-all-storage
        echo "OCP single-node instance: ${SNO_INSTANCE_NAME} deleted"
    fi
}

function create_dnsmasq_config {
    cat << EOF > ${MY_TMP_DIR}/sno.conf
log-queries
dhcp-range=${SNO_MACHINE_NETWORK%%/*},static,${SNO_MACHINE_NETWORK##*/}
address=/apps.sno.lab.example.com/${SNO_HOST_IP}
# Make sure we return NODATA-IPv4. Without this A queries are forwarded,
# and cause lookup delay.
address=/sno.lab.example.com/
address=/apps.sno.lab.example.com/
host-record=api.sno.lab.example.com,${SNO_HOST_IP}
host-record=api-int.sno.lab.example.com,${SNO_HOST_IP}
dhcp-host=${SNO_HOST_MAC},[${SNO_HOST_IP}],2m
EOF
    mkdir -p ${NAT64_IPV6_DNSMASQ_CONF_DIR}/conf.d
    sudo cp -v ${MY_TMP_DIR}/sno.conf ${NAT64_IPV6_DNSMASQ_CONF_DIR}/conf.d/sno.conf
    sudo systemctl restart ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}
}

function cleanup_dnsmasq_config {
    if sudo systemctl is-active ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}; then
        sudo systemctl stop ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}
    fi
    if [ -f ${NAT64_IPV6_DNSMASQ_VAR_DIR}/leasefile ]; then
        sudo sed -i "/${SNO_HOST_IP}/d" ${NAT64_IPV6_DNSMASQ_VAR_DIR}/leasefile
    fi
    rm -f ${NAT64_IPV6_DNSMASQ_CONF_DIR}/sno.conf
    if sudo systemctl is-enabled ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}; then
        sudo systemctl restart ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}
    fi
}

function wait_for_install_complete {
    pushd ${WORK_DIR}

    echo
    echo "Waiting for OCP cluster bootstrapping to complete:"
    echo "${WORK_DIR}/bin/openshift-install --dir=${WORK_DIR}/ocp wait-for bootstrap-complete"
    ./bin/openshift-install --dir=${WORK_DIR}/ocp wait-for bootstrap-complete
    echo
    echo "Waiting for OCP cluster installation to complete:"
    sleep 60
    echo "${WORK_DIR}/bin/openshift-install --dir=${WORK_DIR}/ocp wait-for install-complete"
    ./bin/openshift-install --dir=${WORK_DIR}/ocp wait-for install-complete

    popd
}

function post_config {
    pushd ${WORK_DIR}

    KUBEADMIN_PASSWD=$(cat ./ocp/auth/kubeadmin-password)
    export KUBECONFIG="${WORK_DIR}/ocp/auth/kubeconfig"
    # Create htpasswd file
    htpasswd -c -B -b ${MY_TMP_DIR}/htpasswd admin ${OCP_ADMIN_PASSWD}

    # Get ouath config
    mkdir -p ${MY_TMP_DIR}/oauth
    ./bin/oc get oauth cluster -o yaml > ${MY_TMP_DIR}/oauth/oauth.yaml
    # Add identity provider kustomization
    cat << EOF > ${MY_TMP_DIR}/oauth/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- oauth.yaml
patches:
- patch: |-
    - op: add
      path: /spec/identityProviders
      value:
        - name: htpasswd_provier
          mappingMethod: claim
          type: HTPasswd
          htpasswd:
            fileData:
              name: htpasswd-secret
  target:
    kind: OAuth
EOF
    ./bin/oc kustomize ${MY_TMP_DIR}/oauth/ > ${MY_TMP_DIR}/oauth.yaml
    # Replace oath config
    ./bin/oc replace -f ${MY_TMP_DIR}/oauth.yaml
    # Create htpasswd secret
    ./bin/oc create secret generic htpasswd-secret \
        --from-file htpasswd=${MY_TMP_DIR}/htpasswd \
        -n openshift-config
    # Add Admin privilegies to admin user
    ./bin/oc adm policy add-cluster-role-to-user cluster-admin admin
    echo "Post installation configuration completed"

    popd
}

function create_source_env {
    pushd ${WORK_DIR}

    cat > sno_env << EOF
export KUBECONFIG=${WORK_DIR}/ocp/auth/kubeconfig
export PATH=${WORK_DIR}/bin:$PATH
EOF

    popd
}

function print_cluster_info {
    API_URL="https://api.sno.lab.example.com:6443"
    echo
    echo "Source ${WORK_DIR}/sno_env to set up PATH and KUBECONFIG:"
    echo "      source ${WORK_DIR}/sno_env"
    echo
    echo "Login command (admin):"
    echo "      oc login -u admin -p ${OCP_ADMIN_PASSWD} ${API_URL}"
    echo "Login command (kubeadmin):"
    echo "      oc login -u kubeadmin -p $(cat ${WORK_DIR}/ocp/auth/kubeadmin-password) ${API_URL}"
    echo
    echo "NOTE: It may take a couple of minutes for Identity provider"
    echo "      to be ready ... if you see an authentication error with"
    echo "      the admin user, wait moments and try again."
    echo
}

function create {
    get_oc_client
    get_openshift_installer
    get_rhcos_live_iso
    create_install_iso
    create_dnsmasq_config
    create_sno_instance
    wait_for_install_complete
    post_config
    create_source_env
    print_cluster_info
}

function cleanup {
    destroy_sno_instance
    cleanup_dnsmasq_config
    echo "Cleanup complete"
}

case "$1" in
    "--create")
        ACTION="CREATE";
    ;;
    "--cleanup")
        ACTION="CLEANUP";
    ;;
    *)
        echo >&2 "Invalid option: $*";
        usage;
        exit 1
    ;;
esac

if [ -z "${ACTION}" ]; then
    echo "Not enough input arguments"
    usage
    exit 1
fi

install_dependencies
if [ "${ACTION}" == "CREATE" ]; then
    create
elif [ "${ACTION}" == "CLEANUP" ]; then
    cleanup
fi
