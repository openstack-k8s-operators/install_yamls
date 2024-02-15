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

if [ -z "$CEPH_IMAGE" ]; then
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

CEPH_INDEX=${CEPH_INDEX:-0}
CEPH_TIMEOUT=${CEPH_TIMEOUT:-90}
CEPH_HOSTNETWORK=${CEPH_HOSTNETWORK:-true}
CEPH_POOLS=("volumes" "images" "backups" "cephfs.cephfs.meta" "cephfs.cephfs.data")
CEPH_DAEMONS="osd,mds,rgw"
CEPH_DATASIZE=${CEPH_DATASIZE:-2Gi}
CEPH_WORKER=${CEPH_WORKER:-""}
CEPH_MON_CONF=${CEPH_MON_CONF:-""}
CEPH_DEMO_UID=${CEPH_DAEMON:-0}
OSP_SECRET=${OSP_SECRET:-"osp-secret"}
RGW_USER=${RGW_USER:-"swift"}
RGW_NAME=${RGW_NAME:-"ceph"}
DOMAIN=$(oc -n $NAMESPACE get ingresses.config/cluster -o jsonpath={.spec.domain})
# make input should be called before ceph to make sure we can access this info
RGW_PASS=$(oc -n $NAMESPACE get secrets "$OSP_SECRET" -o jsonpath={.data.SwiftPassword} | base64 -d)
VOLUMEMOUNTS=${VOLUMEMOUNTS:-""}
VOLUMES=${VOLUMES:-""}
RESOURCES=${RESOURCES:-""}


function add_ceph_pod {
cat <<EOF >ceph-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ceph-$index
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: ceph
    app: ceph
spec:
  hostNetwork: $CEPH_HOSTNETWORK
  containers:
   - image: quay.io/ceph/demo:latest-reef
     name: ceph
     env:
     - name: MON_IP
       value: "$MON_IP" $CEPH_MON_CONF
     - name: CEPH_DAEMON
       value: demo
     - name: CEPH_PUBLIC_NETWORK
       value: "0.0.0.0/0"
     - name: DEMO_DAEMONS
       value: "$CEPH_DAEMONS"
     - name: CEPH_DEMO_UID
       value: "$CEPH_DEMO_UID"
     - name: RGW_NAME
       value: "$RGW_NAME"
     volumeMounts: $VOLUMEMOUNTS
     resources: $RESOURCES
  volumes: $VOLUMES
  securityContext:
    runAsUser: 0
    seccompProfile:
      type: Unconfined
  nodeSelector:
    kubernetes.io/hostname: "$CEPH_WORKER"
EOF
}

function ceph_kustomize {
cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ./ceph-pod.yaml
namespace: $NAMESPACE
patches:
- target:
    kind: Pod
  patch: |-
    - op: replace
      path: /metadata/namespace
      value: $NAMESPACE
    - op: replace
      path: /spec/containers/0/image
      value: $CEPH_IMAGE
EOF

if [ -n "${NETWORKS_ANNOTATION}" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /metadata/annotations/k8s.v1.cni.cncf.io~1networks
      value: $NETWORKS_ANNOTATION
EOF
fi
}

function bootstrap_ceph {
    NODES=$(oc -n $NAMESPACE get nodes --selector='node-role.kubernetes.io/worker=' -o 'jsonpath={.items[*].status.addresses[*].address}')
    read -ra values <<< "$NODES"
    [[ -z "$MON_IP" ]] && MON_IP="${values[0]}"
    # we need affinity when we do HOSTNETWORKING
    # hence we schedule the pod to the worker node
    # where the IP address is assigned
    if [ -z "$CEPH_WORKER" ]; then
        CEPH_WORKER="${values[1]}"
    fi
}

function ceph_is_ready {
    local index="$1"
    echo "Waiting the cluster to be up"
    until oc rsh -n $NAMESPACE "ceph-$index" ls /etc/ceph/I_AM_A_DEMO &> /dev/null; do
        sleep 1
        echo -n .
        (( CEPH_TIMEOUT-- ))
        [[ "$CEPH_TIMEOUT" -eq 0 ]] && exit 1
    done
    echo
}

function create_pool {
    local index="$1"

    [ "${#CEPH_POOLS[@]}" -eq 0 ] && return;

    for pool in "${CEPH_POOLS[@]}"; do
        app="rbd"
        oc rsh -n $NAMESPACE "ceph-$index" ceph osd pool create $pool 4
        [[ $pool = *"cephfs"* ]] && app=cephfs
        oc rsh -n $NAMESPACE "ceph-$index" ceph osd pool application enable $pool $app
    done
}

function build_caps {
    local CAPS=""
    for pool in "${CEPH_POOLS[@]}"; do
        caps="allow rwx pool="$pool
        CAPS+=$caps,
    done
    echo "${CAPS::-1}"
}

function create_key {
    local client=$1
    local caps
    local osd_caps
    local index=$2

    if [ "${#CEPH_POOLS[@]}" -eq 0 ]; then
        osd_caps="allow *"
    else
        caps=$(build_caps)
        osd_caps="allow class-read object_prefix rbd_children, $caps"
    fi
    # do not log the key if exists
    oc rsh -n $NAMESPACE "ceph-$index" ceph auth get-or-create "$client" mgr "allow rw" mon "allow r" osd "$osd_caps" >/dev/null
}

function create_secret {

    SECRET_NAME="$1"
    local index="$2"
    TEMPDIR=`mktemp -d`
    local client="client.openstack"
    trap 'rm -rf -- "$TEMPDIR"' EXIT
    # Generate minimal ceph.conf that will be used to access the cluster
    echo "Generate minimal ceph-$index.conf"
    oc rsh -n $NAMESPACE "ceph-$index" ceph config generate-minimal-conf > $TEMPDIR/ceph-$index.conf
    echo 'Create OpenStack keyring'
    # we build the cephx openstack key
    create_key "$client" "$index"
    # do not log the exported key
    echo "Copying OpenStack keyring from the container to $TEMPDIR"
    oc rsh -n $NAMESPACE "ceph-$index" ceph auth export "$client" -o /etc/ceph/ceph-$index.$client.keyring >/dev/null
    oc rsync -n $NAMESPACE "ceph-$index":/etc/ceph/ceph-$index.$client.keyring $TEMPDIR
    echo "Replacing openshift secret $SECRET_NAME"
    oc delete secret "$SECRET_NAME" -n $NAMESPACE 2>/dev/null || true
    oc create secret generic $SECRET_NAME --from-file=$TEMPDIR/ceph-$index.conf --from-file=$TEMPDIR/ceph-$index.$client.keyring -n $NAMESPACE
}

function create_volume {
    # Create cephfs volume for manila service
    local index="$1"
    echo "Creating cephfs volume"
    oc rsh -n $NAMESPACE "ceph-$index" ceph fs volume create cephfs >/dev/null || true
}

function config_ceph {
    local index="$1"
    # Define any config option that should be set in the mgr database
    # via associative arrays and inject to the Ceph Pod
    # Define and set config options
    echo "Apply Ceph config keys"
    declare -A config_keys=(
        ["rgw_keystone_url"]="http://keystone-public-$NAMESPACE.$DOMAIN"
        ["rgw_keystone_verify_ssl"]="true"
        ["rgw_keystone_api_version"]="3"
        ["rgw_keystone_accepted_roles"]="\"member, Member, admin\""
        ["rgw_keystone_accepted_admin_roles"]="\"ResellerAdmin, swiftoperator\""
        ["rgw_keystone_admin_domain"]="default"
        ["rgw_keystone_admin_project"]="service"
        ["rgw_keystone_admin_user"]="$RGW_USER"
        ["rgw_keystone_admin_password"]="$RGW_PASS"
        ["rgw_keystone_implicit_tenants"]="true"
        ["rgw_s3_auth_use_keystone"]="true"
        ["rgw_swift_versioning_enabled"]="true"
        ["rgw_swift_enforce_content_length"]="true"
        ["rgw_swift_account_in_url"]="true"
        ["rgw_trust_forwarded_https"]="true"
        ["rgw_max_attr_name_len"]="128"
        ["rgw_max_attrs_num_in_req"]="90")

    # Apply config settings to Ceph
    for key in "${!config_keys[@]}"; do
        oc exec -n $NAMESPACE -it "ceph-$index" -- sh -c "ceph config set global $key ${config_keys[$key]}"
    done
}

function config_rgw {
    local index="$1"
    echo "Restart RGW and reload the config"
    oc -n $NAMESPACE rsh "ceph-$index" pkill radosgw
    # RGW data and options
    name="client.rgw.$RGW_NAME"
    path="/var/lib/ceph/radosgw/ceph-rgw.$RGW_NAME/keyring"
    options=" --default-log-to-stderr=true --err-to-stderr=true --default-log-to-file=false"
    oc -n $NAMESPACE rsh "ceph-$index" radosgw --cluster ceph --setuser ceph --setgroup ceph "$options" -n "$name" -k "$path"
}

function usage {
    # Display Help
    echo
    echo "Relevant Parameters"
    echo
    echo "* CEPH_HOSTNETWORK: true by default, used to bind the pod to the hostNetwork of the worker node"
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
        echo  "3. NETWORKS_ANNOTATION="[{\"Name\":\"storage\",\"Namespace\":\"$NAMESPACE\"}]" make ceph # attach the NAD to the POD provided it's precreated."
        echo
        echo  "4. CEPH_HOSTNETWORK=false NETWORKS_ANNOTATION=\'[{\"Name\":\"storage\",\"Namespace\":\"$NAMESPACE\",\"ips\":[\"172\.18\.0\.51\/24\"]}]\' MON_IP="172.18.0.51" make ceph # example of binding the Ceph Pod to the storage NAD"
        echo
    fi
}

## RUN THE ACTION
function run {
    local action="$1"
    local index="$2"
    case "$action" in
        "build")
            bootstrap_ceph
            add_ceph_pod "$index"
            ceph_kustomize
            kustomization_add_resources
            ;;
        "config")
            config_ceph "$index"
            ;;
        "secret")
            create_secret "ceph-conf-files-$index" "$index"
            ;;
        "pools")
            create_pool "$index"
            ;;
        "isready")
            ceph_is_ready "$index"
            ;;
        "cephfs")
            create_volume "$index"
            ;;
        "help")
            usage "$2"
            ;;
        "post")
            config_rgw "$index"
            ;;
    esac
}


# MAIN
function make_ceph {
    local index="$1"
    run "build" "$index"
    DEPLOY_DIR=${DEPLOY_DIR}/ceph-"$index" . ${SCRIPTPATH}/operator-deploy-resources.sh
    run "isready" "$index"
    run "config" "$index"
    run "cephfs" "$index"
    run "pools" "$index"
    run "secret" "$index"
    run "post" "$index"
}

if [[ "$CEPH_INDEX" -eq 0 ]]; then
VOLUMEMOUNTS=$(cat <<END

       - mountPath: /var/lib/ceph
         name: "data-0"
       - mountPath: /var/log/ceph
         name: "log-0"
       - mountPath: /run/ceph
         name: "run-0"
       - mountPath: /etc/ceph
         name: "etc-0"
END
)
VOLUMES=$(cat <<END

  - name: "etc-0"
    emptyDir:
      sizeLimit: "$CEPH_DATASIZE"
  - name: "data-0"
    emptyDir:
      sizeLimit: "$CEPH_DATASIZE"
  - name: "run-0"
    emptyDir:
      sizeLimit: "$CEPH_DATASIZE"
  - name: "log-0"
    emptyDir:
      sizeLimit: "$CEPH_DATASIZE"
END
)
else
RESOURCES=$(cat <<END

       requests:
         ephemeral-storage: "$CEPH_DATASIZE"
       limits:
         ephemeral-storage: "$CEPH_DATASIZE"
END
)
echo "WARNING: Can't use HOSTNETWORKING with Multiple Ceph clusters on the same node"
CEPH_HOSTNETWORK="false"
fi

# if CEPH_HOSTNETWORK is false, we always need
# to produce the following snippet that is
# supposed to get the IP assigned to the
# POD and pass it to the MON process.
if [[ "$CEPH_HOSTNETWORK" == "false" ]]; then
MON_IP="0.0.0.0"
CEPH_MON_CONF=$(cat <<END

     - name: MON_IP
       valueFrom:
         fieldRef:
           fieldPath: status.podIP
END
)
fi

# deploy ceph
for ((i=0; i<$CEPH_INDEX; i++)); do
    mkdir -p -p "$DEPLOY_DIR"/ceph-"$i"
    pushd "$DEPLOY_DIR"/ceph-"$i"
    make_ceph "$i"
    popd
done
