#!/bin/bash
# set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit
fi

function usage {
    echo
    echo "options:"
    echo "  --create     Create crc-bmaas sushy-emulator"
    echo "  --cleanup    Cleanup crc-bmaas sushy-emulator"
    echo
}

MY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$MY_TMP_DIR"' EXIT

NODE_NAME_PREFIX=${NODE_NAME_PREFIX:-"crc-bmaas"}
NAMESPACE=${SUSHY_EMULATOR_NAMESPACE:-"sushy-emulator"}
DRIVER=${SUSHY_EMULATOR_DRIVER:-"libvirt"}
INGRESS_DOMAIN=$(oc get ingresses.config/cluster -o jsonpath={.spec.domain})
REDFISH_USERNAME=${REDFISH_USERNAME:-"admin"}
REDFISH_PASSWORD=${REDFISH_PASSWORD:-"password"}
IMAGE=${SUSHY_EMULATOR_IMAGE:-"quay.io/metal3-io/sushy-tools:latest"}

if [ $DRIVER = "libvirt" ]; then
    CRC_NETWORK_NAME=crc
    SSH_ALGORITHM=rsa
    SSH_KEY_FILE=bmaas-ssh-key-id_rsa
    SSH_KEY_SIZE=4096
    LIBVIRT_USER=${LIBVIRT_USER:-"sushyemu"}
    if sudo systemctl is-active libvirtd.service; then
        LIBVIRT_SOCKET="?socket=/var/run/libvirt/libvirt-sock"
    else
        LIBVIRT_SOCKET=""
    fi
    # TODO: Make CRC_NETWORK_NAME a parameter so that this script can be used on
    # separate hypervisor, against any OCP.
    LIBVIRT_IP_ADDRESS=$(nmcli connection show "${CRC_NETWORK_NAME}" | grep ipv4.addresses | cut -d / -f 1 | awk '{ print $2 }')
    INSTANCES=$(virsh --connect=qemu:///system list --all --uuid --name | grep "${NODE_NAME_PREFIX}" | awk '{ printf "\"" $1 "\" " }' | sed -e 's/" "/", "/' -e 's/^"/["/' -e 's/" $/"]/')
    LIBVIRT_URI="'qemu+ssh://${LIBVIRT_USER}@${LIBVIRT_IP_ADDRESS}/system${LIBVIRT_SOCKET}'"
    EMULATOR_OS_CLOUD="None"
elif [ $DRIVER = "openstack" ]; then
    OS_CLIENT_CONFIG_FILE=${SUSHY_EMULATOR_OS_CLIENT_CONFIG_FILE:-/etc/openstack/clouds.yaml}
    INSTANCES=$(openstack --os-cloud=${SUSHY_EMULATOR_OS_CLOUD} server list --name "edpm-compute.*" -f json -c ID | jq -c [.[].ID])
    LIBVIRT_URI="None"
    EMULATOR_OS_CLOUD="'${SUSHY_EMULATOR_OS_CLOUD}'"
fi

function create_sushy_emulator_namespace {
    echo "Creating namespace ${NAMESPACE}"
    cat <<EOF > "${MY_TMP_DIR}/namespace.yaml"
apiVersion: v1
kind: Namespace
metadata:
    name: ${NAMESPACE}
EOF

    # cat ${MY_TMP_DIR}/namespace.yaml
    oc apply -f "${MY_TMP_DIR}/namespace.yaml"
}

function create_sushy_emulator_user {
    echo "Creating sushy emulator libvirt user - and add to libvirt group"
    if ! getent passwd "${LIBVIRT_USER}" > /dev/null 2>&1; then
        # sudo useradd ${LIBVIRT_USER} --shell /usr/sbin/nologin
        sudo useradd "${LIBVIRT_USER}"
    fi
    sudo usermod --groups libvirt --append "${LIBVIRT_USER}"
}

function generate_ssh_keypair {
    echo "Generate sushy emulator SSH keypair - and set up ${LIBVIRT_USER} users authorized_keys"
    local homedir
    homedir=$(getent passwd "${LIBVIRT_USER}" | cut -d: -f6)
    if [ -z "$homedir" ]; then
        echo "PANIC, unable to get ${LIBVIRT_USER} home directory."
        exit 1
    fi
    ssh-keygen -q -f "${MY_TMP_DIR}/${SSH_KEY_FILE}" -N "" -t "${SSH_ALGORITHM}" -b "${SSH_KEY_SIZE}"
    sudo mkdir -p "${homedir}/.ssh"
    sudo cp "${MY_TMP_DIR}/${SSH_KEY_FILE}" "${homedir}/.ssh/${SSH_KEY_FILE}"
    sudo cp "${MY_TMP_DIR}/${SSH_KEY_FILE}.pub" "${homedir}/.ssh/${SSH_KEY_FILE}.pub"
    sudo touch "${homedir}/.ssh/authorized_keys"
    cat "${MY_TMP_DIR}/${SSH_KEY_FILE}.pub" | sudo tee "${homedir}/.ssh/authorized_keys" > /dev/null
    sudo chown -R "${LIBVIRT_USER}":"${LIBVIRT_USER}" "${homedir}/.ssh"
    sudo chmod 700 "${homedir}/.ssh"
    sudo chmod -R og-rwx "${homedir}/.ssh"
}

function create_sushy_emulator_config {
    echo "Creating sushy-emulator-config"
    cat << EOF > "${MY_TMP_DIR}/config-map.yaml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: sushy-emulator-config
  namespace: ${NAMESPACE}
data:
  htpasswd: |
$(htpasswd -nbB "${REDFISH_USERNAME}" "${REDFISH_PASSWORD}" | sed 's/^/    /')
  config: |
    # Listen on all local IP interfaces
    SUSHY_EMULATOR_LISTEN_IP = '0.0.0.0'

    # Bind to TCP port 8000
    SUSHY_EMULATOR_LISTEN_PORT = 8000

    # Serve this SSL certificate to the clients
    SUSHY_EMULATOR_SSL_CERT = None

    # If SSL certificate is being served, this is its RSA private key
    SUSHY_EMULATOR_SSL_KEY = None

    # If authentication is desired, set this to an htpasswd file.
    SUSHY_EMULATOR_AUTH_FILE = '/etc/sushy-emulator/.htpasswd'

    # The OpenStack cloud ID to use. This option enables OpenStack driver.
    SUSHY_EMULATOR_OS_CLOUD = ${EMULATOR_OS_CLOUD}

    # The libvirt URI to use. This option enables libvirt driver.
    SUSHY_EMULATOR_LIBVIRT_URI = ${LIBVIRT_URI}

    # Instruct the libvirt driver to ignore any instructions to
    # set the boot device. Allowing the UEFI firmware to instead
    # rely on the EFI Boot Manager
    # Note: This sets the legacy boot element to dev="fd"
    # and relies on the floppy not existing, it likely wont work
    # your VM has a floppy drive.
    SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = False

    # This list contains the identities of instances that the driver will filter by.
    # It is useful in a tenant environment where only some instances represent
    # virtual baremetal.
    SUSHY_EMULATOR_ALLOWED_INSTANCES = ${INSTANCES}
EOF

    # cat ${MY_TMP_DIR}/config-map.yaml
    oc apply -f "${MY_TMP_DIR}/config-map.yaml"
}

function create_sushy_emulator_secret {
    echo "Creating sushy-emulator-secret"
    if [ $DRIVER = "libvirt" ]; then
        cat << EOF > "${MY_TMP_DIR}/secret.yaml"
apiVersion: v1
kind: Secret
metadata:
    name: sushy-emulator-secret
    namespace: ${NAMESPACE}
data:
    ssh-publickey: |
$(base64 < "${MY_TMP_DIR}/${SSH_KEY_FILE}.pub" | sed 's/^/        /')
    ssh-privatekey: |
$(base64 < "${MY_TMP_DIR}/${SSH_KEY_FILE}" | sed 's/^/        /')
    ssh-known-hosts: |
$(ssh-keyscan -H "${LIBVIRT_IP_ADDRESS}" | base64 | sed 's/^/        /')
---
apiVersion: v1
kind: Secret
metadata:
    name: os-client-config
    namespace: ${NAMESPACE}
data:
    openstack-clouds-yaml: ""
EOF
    elif [ $DRIVER = "openstack" ]; then
        cat << EOF > "${MY_TMP_DIR}/secret.yaml"
apiVersion: v1
kind: Secret
metadata:
    name: sushy-emulator-secret
    namespace: ${NAMESPACE}
data:
    ssh-publickey: ""
    ssh-privatekey: ""
    ssh-known-hosts: ""
---
apiVersion: v1
kind: Secret
metadata:
    name: os-client-config
    namespace: ${NAMESPACE}
data:
    openstack-clouds-yaml: |
$(cat ${OS_CLIENT_CONFIG_FILE} | base64 | sed 's/^/        /')
EOF
    fi

    # cat ${MY_TMP_DIR}/secret.yaml
    oc apply -f "${MY_TMP_DIR}/secret.yaml"
}

function create_sushy_emulator_pod {
    echo "Creating sushy-emulator pod"
    cat << EOF > "${MY_TMP_DIR}/sushy-emulator-pod.yaml"
---
apiVersion: v1
kind: Pod
metadata:
  name: sushy-emulator
  namespace: ${NAMESPACE}
  labels:
    name: sushy-emulator
spec:
  selector:
    app.kubernetes.io/name: sushy-emulator
  containers:
  - name: sushy-emulator
    image: ${IMAGE}
    command: ["/usr/local/bin/sushy-emulator", "--config", "/etc/sushy-emulator/config.conf"]
    ports:
    - containerPort: 8000
    volumeMounts:
    - name: ssh-secret
      mountPath: /root/.ssh
      readOnly: true
    - name: sushy-emulator-config
      mountPath: /etc/sushy-emulator/
    - name: os-client-config
      mountPath: /etc/openstack/
    readinessProbe:
      httpGet:
        path: redfish/v1
        port: 8000
        initialDelaySeconds: 5
        periodSeconds: 5
    livenessProbe:
      httpGet:
        path: redfish/v1
        port: 8000
        initialDelaySeconds: 10
        failureThreshold: 30
        periodSeconds: 10
    startupProbe:
      httpGet:
        path: redfish/v1
        port: 8000
        failureThreshold: 30
        initialDelaySeconds: 10
  volumes:
  - name: ssh-secret
    secret:
      secretName: sushy-emulator-secret
      defaultMode: 0644 # u=rw,g=r,o=r
      items:
      - key: ssh-privatekey
        path: id_rsa
        mode: 0600 # u=rw,g=,o=
      - key: ssh-publickey
        path: id_rsa.pub
        mode: 0644 # u=rw,g=r,o=r
      - key: ssh-known-hosts
        path: known_hosts
        mode: 0644 # u=rw,g=r,o=r
  - name: sushy-emulator-config
    configMap:
      name: sushy-emulator-config
      defaultMode: 0644 # u=rw,g=r,o=r
      items:
      - key: config
        path: config.conf
      - key: htpasswd
        path: .htpasswd
        mode: 0600 # u=rw,g=r,o=r
  - name: os-client-config
    secret:
      secretName: os-client-config
      defaultMode: 0644 # u=rw,g=r,o=r
      items:
      - key: openstack-clouds-yaml
        path: clouds.yaml
  restartPolicy: OnFailure
EOF

    # cat ${MY_TMP_DIR}/sushy-emulator-pod.yaml
    oc apply -f "${MY_TMP_DIR}/sushy-emulator-pod.yaml"
}

function create_sushy_emulator_service {
    echo "Creating sushy-emulator-service"
    cat << EOF > "${MY_TMP_DIR}/sushy-emulator-service.yaml"
---
apiVersion: v1
kind: Service
metadata:
  name: sushy-emulator-service
  namespace: ${NAMESPACE}
  labels:
    name: sushy-emulator
spec:
  selector:
    name: sushy-emulator
  ports:
  - protocol: TCP
    port: 8000
    targetPort: 8000
EOF

    # cat ${MY_TMP_DIR}/sushy-emulator-service.yaml
    oc apply -f "${MY_TMP_DIR}/sushy-emulator-service.yaml"
}

function create_sushy_emulator_route {
    echo "Creating sushy-emulator-route"
    cat << EOF > "${MY_TMP_DIR}/sushy-emulator-route.yaml"
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: sushy-emulator-route
  namespace: ${NAMESPACE}
  labels:
    name: sushy-emulator
spec:
  host: sushy-emulator.${INGRESS_DOMAIN}
  port:
    targetPort: 8000
  to:
    kind: Service
    name: sushy-emulator-service
EOF

    # cat ${MY_TMP_DIR}/sushy-emulator-route.yaml
    oc apply -f "${MY_TMP_DIR}/sushy-emulator-route.yaml"
}

function create {
    if ! rpm --quiet -q --whatprovides httpd-tools; then
        sudo dnf -y install httpd-tools || { echo "Unable to install dependency httpd-tools"; exit 1; }
    fi
    if [ $DRIVER = "libvirt" ]; then
        create_sushy_emulator_user
        generate_ssh_keypair
    fi
    create_sushy_emulator_namespace
    create_sushy_emulator_config
    create_sushy_emulator_secret
    create_sushy_emulator_pod
    create_sushy_emulator_service
    create_sushy_emulator_route
}

function cleanup {
    if oc get project.v1.project.openshift.io "${NAMESPACE}" > /dev/null 2>&1; then
        oc delete project "${NAMESPACE}" --wait=true
    else
        echo "Not deleting namespace ${NAMESPACE}, it does not exist"
    fi
    if [ $DRIVER = "libvirt" ]; then
        if getent passwd "${LIBVIRT_USER}" > /dev/null 2>&1; then
            echo -n "Deleting user ${LIBVIRT_USER}"
            sudo userdel --remove "${LIBVIRT_USER}" && echo " :: OK" || echo " :: ERROR - failed to delete user"
        else
            echo "Not deleting user ${LIBVIRT_USER}, user does not exist"
        fi
    fi
}

case "$1" in
    "--create")
        create;
    ;;
    "--cleanup")
        cleanup;
    ;;
    *)
        echo >&2 "Invalid option: $*";
        usage;
        exit 1
    ;;
esac
