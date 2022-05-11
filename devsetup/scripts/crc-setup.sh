#!/bin/bash
# set -x

if [ "$EUID" -eq 0 ]
  then echo "Please do not run as root."
  exit
fi

CRC_URL=$1
KUBEADMIN_PWD=$2
PULL_SECRET_FILE=$3

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
if [ -z "${CRC_BIN}" ]; then
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
crc config set skip-check-daemon-systemd-unit true
crc config set skip-check-daemon-systemd-sockets true
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
