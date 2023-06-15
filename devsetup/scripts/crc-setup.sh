#!/bin/bash
# set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit
fi

CRC_URL=$1
KUBEADMIN_PWD=$2
PULL_SECRET_FILE=$3
CRC_BUNDLE=${CRC_BUNDLE:-""}
CPUS=${CPUS:-4}
MEMORY=${MEMORY:-9216}
DISK=${DISK:-31}

if [ -z "${CRC_URL}" ]; then
    echo "Please set CRC_URL as ARG1"; exit 1
fi
if [ -z "${KUBEADMIN_PWD}" ]; then
    echo "Please set KUBEADMIN_PWD as ARG2"; exit 1
fi
if [ -z "${PULL_SECRET_FILE}" ]; then
    echo "Please set PULL_SECRET_FILE as ARG3"; exit 1
fi
# verify pull secret file exist
if [ ! -f "${PULL_SECRET_FILE}" ]; then
    echo "Pull secret file ${PULL_SECRET_FILE} does not exist, Please download from https://cloud.redhat.com/openshift/create/local"; exit 1
fi

CRC_BIN=$(which crc)
export_path=0
if [ -z "${CRC_BIN}" ]; then
    export PATH="~/bin:${PATH}"
    export_path=1
    mkdir -p ~/bin
    curl -L "${CRC_URL}" | tar -U --strip-components=1 -C ~/bin -xJf - *crc
    CRC_BIN=$(which crc)
fi

# config CRC
${CRC_BIN} config set consent-telemetry no
${CRC_BIN} config set kubeadmin-password ${KUBEADMIN_PWD}
${CRC_BIN} config set pull-secret-file ${PULL_SECRET_FILE}
# Executing systemctl action failed:  exit status 1: Failed to connect to bus: No such file or directory
# https://github.com/code-ready/crc/issues/2674
${CRC_BIN} config set skip-check-daemon-systemd-unit true
${CRC_BIN} config set skip-check-daemon-systemd-sockets true
${CRC_BIN} config set cpus ${CPUS}
${CRC_BIN} config set memory ${MEMORY}
${CRC_BIN} config set disk-size ${DISK}
if [ -n ${CRC_BUNDLE} ]; then
    ${CRC_BIN} config set bundle ${CRC_BUNDLE}
fi
${CRC_BIN} setup

${CRC_BIN} start
${CRC_BIN} console --credentials # get the kubeadmin login and then login

# add crc provided oc client to PATH
eval $(${CRC_BIN} oc-env)

# login to crc env
oc login -u kubeadmin -p ${KUBEADMIN_PWD} https://api.crc.testing:6443

# make sure you can push to the internal registry; without this step you'll get x509 errors
echo -n "Adding router-ca to system certs to allow accessing the crc image registry"
oc extract secret/router-ca --keys=tls.crt -n openshift-ingress-operator --confirm --to=/tmp
sudo cp -f /tmp/tls.crt /etc/pki/ca-trust/source/anchors/crc-router-ca.pem
sudo update-ca-trust
if [ $export_path == 1 ]; then
    echo "WARNING: you must add ~/bin in your PATH in order to access to crc binary"
fi

# apply post-config tweaks
oc patch etcd cluster -p='{"spec": {"unsupportedConfigOverrides": {"useUnsupportedUnsafeNonHANonProductionUnstableEtcd": true}}}' --type=merge
oc patch authentications.operator.openshift.io cluster -p='{"spec": {"unsupportedConfigOverrides": {"useUnsupportedUnsafeNonHANonProductionUnstableOAuthServer": true}}}' --type=merge
oc scale --replicas=1 ingresscontroller/default -n openshift-ingress-operator
oc scale --replicas=0 deployment.apps/console -n openshift-console
oc scale --replicas=1 deployment.apps/downloads -n openshift-console
oc scale --replicas=1 deployment.apps/oauth-openshift -n openshift-authentication
oc scale --replicas=1 deployment.apps/packageserver -n openshift-operator-lifecycle-manager
oc scale --replicas=0 deployment.apps/cluster-monitoring-operator -n openshift-monitoring
oc delete project openshift-monitoring
