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
# set -ex

# expect that the common.sh is in the same dir as the calling script
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
. ${SCRIPTPATH}/common.sh --source-only

if [ -z "$IMAGE" ]; then
    echo "Unable to determine ceph image."
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE."
    exit 1
fi

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

pushd ${DEPLOY_DIR}

TIMEOUT=${TIMEOUT:-30}
HOSTNETWORK=${HOSTNETWORK:-true}
POOLS=("volumes" "images" "backups" "cephfs.cephfs.meta" "cephfs.cephfs.data")
DAEMONS="osd,mds"

function add_ceph_pod {
cat <<EOF >ceph-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    k8s.v1.cni.cncf.io/networks: ""
  name: ceph
  namespace: openstack
  labels:
    app.kubernetes.io/name: ceph
    app: ceph
spec:
  hostNetwork: $HOSTNETWORK
  containers:
   - image: quay.io/ceph/daemon:latest-quincy
     name: ceph
     env:
     - name: MON_IP
       value: "$MON_IP"
     - name: CEPH_DAEMON
       value: demo
     - name: CEPH_PUBLIC_NETWORK
       value: "0.0.0.0/0"
     - name: DEMO_DAEMONS
       value: "$DAEMONS"
     volumeMounts:
      - mountPath: /var/lib/ceph
        name: data
      - mountPath: /var/log/ceph
        name: log
      - mountPath: /run/ceph
        name: run
  volumes:
  - name: data
    emptyDir:
      sizeLimit: 500Mi
  - name: run
    emptyDir:
      sizeLimit: 500Mi
  - name: log
    emptyDir:
      sizeLimit: 500Mi
  securityContext:
    runAsUser: 0
    seccompProfile:
      type: Unconfined
EOF
}

function ceph_kustomize {
cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ./ceph-pod.yaml
namespace: openstack
patches:
- target:
    kind: Pod
  patch: |-
    - op: replace
      path: /metadata/namespace
      value: $NAMESPACE
    - op: replace
      path: /spec/containers/0/image
      value: $IMAGE
    - op: replace
      path: /metadata/annotations/k8s.v1.cni.cncf.io~1networks
      value: $NETWORKS_ANNOTATION
EOF
}

function get_pod_ip {
    if [[ "$HOSTNETWORK" == "false" ]]; then
        echo "HOSTNETWORK must be set to true!"
        exit 1
    fi
    MON_IP=$(oc get nodes -o 'jsonpath={.items[*].status.addresses[?(.type=="InternalIP")].address}')
}

function ceph_is_ready {
    echo "Waiting the cluster to be up"
    until oc rsh ceph ls /etc/ceph/I_AM_A_DEMO &> /dev/null; do
        sleep 1
        echo -n .
        (( TIMEOUT-- ))
        [[ "$TIMEOUT" -eq 0 ]] && exit 1
    done
    echo
}

function create_pool {

    [ "${#POOLS[@]}" -eq 0 ] && return;

    for pool in "${POOLS[@]}"; do
        app="rbd"
        oc rsh ceph ceph osd pool create $pool 4
        [[ $pool = *"cephfs"* ]] && app=cephfs
        oc rsh ceph ceph osd pool application enable $pool $app
    done
}

function build_caps {
    local CAPS=""
    for pool in "${POOLS[@]}"; do
        caps="allow rwx pool="$pool
        CAPS+=$caps,
    done
    echo "${CAPS::-1}"
}

function create_key {
    local client=$1
    local caps
    local osd_caps

    if [ "${#POOLS[@]}" -eq 0 ]; then
        osd_caps="allow *"
    else
        caps=$(build_caps)
        osd_caps="allow class-read object_prefix rbd_children, $caps"
    fi
    # do not log the key if exists
    oc rsh ceph ceph auth get-or-create "$client" mgr "allow rw" mon "allow r" osd "$osd_caps" >/dev/null
}

function create_secret {

    SECRET_NAME="$1"

    TEMPDIR=`mktemp -d`
    local client="client.openstack"
    trap 'rm -rf -- "$TEMPDIR"' EXIT
    echo 'Copying Ceph config files from the container to $TEMPDIR'
    oc rsync ceph:/etc/ceph/ceph.conf $TEMPDIR
    echo 'Create OpenStack keyring'
    # we build the cephx openstack key
    create_key "$client"
    # do not log the exported key
    echo 'Copying OpenStack keyring from the container to $TEMPDIR'
    oc rsh ceph ceph auth export "$client" -o /etc/ceph/ceph.$client.keyring >/dev/null
    oc rsync ceph:/etc/ceph/ceph.$client.keyring $TEMPDIR

    echo "Replacing openshift secret $SECRET_NAME"
    oc delete secret "$SECRET_NAME" -n $NAMESPACE 2>/dev/null || true
    oc create secret generic $SECRET_NAME --from-file=$TEMPDIR/ceph.conf --from-file=$TEMPDIR/ceph.$client.keyring -n $NAMESPACE
}

function create_volume {
    # Create cephfs volume for manila service
    echo "Creating cephfs volume"
    oc rsh ceph ceph fs volume create cephfs >/dev/null || true
}

function usage {
    # Display Help
    echo
    echo "Relevant Parameters"
    echo
    echo "* HOSTNETWORK: true by default, used to bind the pod to the hostNetwork of the worker node"
    echo "* MON_IP: the IP address (if known in  advance) to bind the mon when the cluster is run"
    echo "* NETWORKS_ANNOTATION: the NAD(s) that will be applied to the pod using kustomize"
    echo

    if [[ "$1" == "full" ]]; then
        echo
        echo "Syntax: $0 [build|isready|help|secret]" 1>&2;
        echo
        echo "Examples"
        echo

        echo  "1. make ceph # the pod is bound to the hostNetwork by default"
        echo
        echo  "2. MON_IP=<YOUR_HOST_IP_ADDRESS> make ceph # the pod uses hostNetworking and the container will be bound to the specified ip address"
        echo
        echo  "3. NETWORKS_ANNOTATION="[{\"Name\":\"storage\",\"Namespace\":\"openstack\"}]" make ceph # attach the NAD to the POD provided it's precreated."
        echo
        echo  "4. HOSTNETWORK=false NETWORKS_ANNOTATION=\'[{\"Name\":\"storage\",\"Namespace\":\"openstack\",\"ips\":[\"172\.18\.0\.51\/24\"]}]\' MON_IP="172.18.0.51" make ceph # example of binding the Ceph Pod to the storage NAD"
        echo
    fi
}

## MAIN
case "$1" in
    "build")
        [[ -z "$MON_IP" ]] && get_pod_ip;
        add_ceph_pod
        ceph_kustomize
        kustomization_add_resources
        ;;
    "secret")
        create_secret "ceph-conf-files"
        ;;
    "pools")
        create_pool
        ;;
    "isready")
        ceph_is_ready
        ;;
    "cephfs")
        create_volume
        ;;
    "help")
        usage "$2"
        ;;
esac
