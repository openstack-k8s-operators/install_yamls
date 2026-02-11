#!/bin/bash
#
# Copyright 2024 Red Hat Inc.
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
set -ex

# expect that the common.sh is in the same dir as the calling script
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
. ${SCRIPTPATH}/common.sh --source-only

CEPH_HOSTNETWORK=${CEPH_HOSTNETWORK:-true}
CEPH_POOLS=("volumes" "images" "backups" "cephfs.cephfs.meta" "cephfs.cephfs.data")
CEPH_NAMESPACE=${CEPH_NAMESPACE:-"rook-ceph"}
CEPH_NODE=${2:-"crc"}

if [ -z "$IMAGE" ]; then
    echo "Unable to determine ceph image."
    exit 1
fi

if [ ! -d "${DEPLOY_DIR}" ]; then
    mkdir -p "${DEPLOY_DIR}"
fi

pushd "${DEPLOY_DIR}"

function ceph_is_ready {
    timeout "${TIMEOUT}" bash -c "while ! (oc wait CephCluster ceph -n ${CEPH_NAMESPACE} --for condition=Ready); do sleep 10; done"
}

function get_tools {
    TOOLS_POD=$(oc get pods -n "$CEPH_NAMESPACE" -o custom-columns=NAME:.metadata.name --no-headers | grep tools)
    if [ -z "$TOOLS_POD" ]; then
        echo "Unable to get ceph-tools Pod."
        exit 1
    fi
}

function create_pool {
    get_tools
    [ "${#CEPH_POOLS[@]}" -eq 0 ] && return;
    for pool in "${CEPH_POOLS[@]}"; do
        app="rbd"
        oc rsh -n "$CEPH_NAMESPACE" "$TOOLS_POD" ceph osd pool create "$pool" 4
        [[ $pool = *"cephfs"* ]] && app=cephfs
        oc rsh -n "$CEPH_NAMESPACE" "$TOOLS_POD" ceph osd pool application enable "$pool" "$app"
    done
}

function build_caps {
    local CAPS=""
    for pool in "${CEPH_POOLS[@]}"; do
        caps="profile rbd pool="$pool
        CAPS+=$caps,
    done
    echo "${CAPS::-1}"
}

function create_key {
    get_tools
    local client=$1
    local caps
    local osd_caps
    if [ "${#CEPH_POOLS[@]}" -eq 0 ]; then
        osd_caps="allow *"
    else
        osd_caps=$(build_caps)
    fi
    # do not log the key if exists
    oc rsh -n "$CEPH_NAMESPACE" "$TOOLS_POD" ceph auth get-or-create "$client" mgr "allow *" mon "profile rbd" osd "$osd_caps" >/dev/null
}

function create_secret {
    get_tools
    SECRET_NAME="$1"
    TEMPDIR=`mktemp -d`
    local client="client.openstack"
    trap 'rm -rf -- "$TEMPDIR"' EXIT
    echo "Copying Ceph config files from the container to $TEMPDIR"
    oc rsync -n "$CEPH_NAMESPACE" "$TOOLS_POD":/etc/ceph/ceph.conf "$TEMPDIR"
    echo 'Create OpenStack keyring'
    # we build the cephx openstack key
    create_key "$client"
    # do not log the exported key
    echo "Copying OpenStack keyring from the container to $TEMPDIR"
    oc rsh -n "$CEPH_NAMESPACE" "$TOOLS_POD" ceph auth export "$client" -o /etc/ceph/ceph.$client.keyring >/dev/null
    oc rsync -n "$CEPH_NAMESPACE" "$TOOLS_POD":/etc/ceph/ceph.$client.keyring "$TEMPDIR"

    echo "Replacing openshift secret $SECRET_NAME"
    oc delete secret "$SECRET_NAME" -n "$NAMESPACE" 2>/dev/null || true
    oc create secret generic "$SECRET_NAME" --from-file="$TEMPDIR"/ceph.conf --from-file="$TEMPDIR"/ceph.$client.keyring -n "$NAMESPACE"
}

function create_volume {
    # Create cephfs volume for manila service
    echo "Creating cephfs volume"
    oc rsh -n "$CEPH_NAMESPACE" "$TOOLS_POD" ceph fs volume create cephfs >/dev/null || true
}

cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ./cluster-test.yaml
namespace: rook-ceph
patches:
- target:
    kind: CephCluster
  patch: |-
    - op: replace
      path: /spec/cephVersion/image
      value: $IMAGE
    - op: replace
      path: /metadata/name
      value: ceph
    - op: replace
      path: /spec/storage/useAllDevices
      value: false
    - op: replace
      path: /spec/storage/useAllNodes
      value: false
    - op: replace
      path: /spec/dashboard/enabled
      value: false
    - op: add
      path: /spec/storage/nodes
      value:
        - name: "${CEPH_NODE}"
          devices:
            - name: /dev/ceph_vg_1/ceph_lv_data
    - op: add
      path: /spec/mgr/modules/-
      value:
        name: prometheus
        enabled: false

EOF

if [[ "$CEPH_HOSTNETWORK" == "false" ]]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/network
      value: {}
    - op: add
      path: /spec/network/provider
      value: host
EOF
fi

## MAIN
case "$1" in
    "build")
        kustomization_add_resources
        ;;
    "cephfs")
        create_volume
        ;;
    "isready")
        ceph_is_ready
        ;;
    "pools")
        create_pool
        ;;
    "secret")
        create_secret "ceph-conf-files"
        ;;
esac
