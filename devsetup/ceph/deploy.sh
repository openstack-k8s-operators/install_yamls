#!/bin/env bash

# GENERIC CEPHADM INTERNAL OPTIONS, DO NOT EDIT
TARGET_BIN=/usr/bin
ORIG_CONFIG="$HOME/bootstrap_ceph.conf"
CONFIG="/etc/ceph/ceph.conf"
KEYRING="/etc/ceph/ceph.client.admin.keyring"
CEPH_PUB_KEY="/etc/ceph/ceph.pub"
REQUIREMENTS=("jq" "lvm" "python3")

# DEFAULT OPTIONS
FSID="4b5c8c0a-ff60-454b-a1b4-9747aa737d19"
CONTAINER_IMAGE=${CONTAINER_IMAGE:-'quay.io/ceph/ceph:v19'}
IP=${IP:-'127.0.0.1'}
DEVICES=()
SERVICES=()
KEYS=("client.openstack" "client.rook") # at least the client.openstack default key should be created
KEY_EXPORT_DIR="/etc/ceph"
# DEVICES=("/dev/ceph_vg/ceph_lv_data")
# SERVICES=("RGW" "MDS" "NFS") # monitoring is removed for now
SLEEP=30
ATTEMPTS=30
MIN_OSDS=1
DEBUG=0
# NFS OPTIONS
FSNAME=${FSNAME:-'cephfs'}
NFS_PORT=${NFS_PORT:-2049}
NFS_CLIENT=0
NFS_CLIENT_NAME="client.manila"
NFS_CLIENT_LOG="/var/log/ceph-$NFS_CLIENT_NAME.log"

# POOLS
declare -A POOLS
DEFAULT_PG_NUM=8
DEFAULT_PGP_NUM=8

# RGW OPTIONS
RGW_PORT=8080
RGW_INGRESS=0  # do not deploy the ingress daemon by default
RGW_NET=${RGW_NET:-"$IP"}
RGW_INGRESS_FPORT=8080
RGW_INGRESS_MPORT=8999
RGW_INGRESS_SPEC="rgw_ingress.yml"

RGW_USER=${RGW_USER:-"swift"}
RGW_PASS=${RGW_PASS:-"12345678"}
KEYSTONE_EP=${KEYSTONE_EP:-"http://keystone-public-openstack.apps-crc.testing"}
RGW_CONF=${RGW_CONF:-"rgw_conf.sh"}

# INGRESS CONFIG
VIP=${VIP:-'127.0.0.1'} # the frontend vip managed by keepalived

declare -A INGRESS_IMAGES
INGRESS_IMAGES[haproxy]='2.3'
INGRESS_IMAGES[keepalived]='2.1.5'

# SET K8S to 1 to build a Ceph secret containing both ceph.conf and keyring
K8S=0
EXTERNAL_ROOK=1
ROOK_CLUSTER_NAME=${ROOK_CLUSTER_NAME:-"ocs-external-storagecluster"}
ROOK_NAMESPACE="${ROOK_NAMESPACE:-"openshift-storage"}"
EXPORT_CLUSTER_RESOURCES_FILE="rook-env-vars.sh"
RBD_ROOK_POOL_NAME="${RBD_ROOK_POOL_NAME:-"rook"}"

# ADDITIONAL HOSTS
declare -A HOSTS

# CLIENT CONFIG
RBD_CLIENT_LOG=/var/log/ceph/qemu-guest-$pid.log
CLIENT_CONFIG=$HOME/ceph_client.conf
EXPORT=$HOME/ceph_export.yml

DEV=0
WORKDIR=$HOME/ceph
SHARED_OPT=""

[ -z "$SUDO" ] && SUDO=sudo

# TODO:
#   - feature1 -> add pv/vg/lv for loopback
#   - install cephadm from centos storage sig

get_ceph_cli() {
    MON_NAME=$($SUDO $CEPHADM ls | jq '.[]' | jq 'select(.name | test("^mon*")).name' | sed s/\"//g);
    MON_CID=$($SUDO $CEPHADM ls | jq '.[]' | jq 'select(.name | test("^mon*")).container_id' | sed s/\"//g);
    $(which podman) cp $KEYRING $MON_CID:$KEYRING
    CEPHADM_CLI="$SUDO $CEPHADM enter --name $NAME -- ceph"
}

distribute_keys() {
    local ip="$1"
    ssh-copy-id -o StrictHostKeyChecking=no -i "$DEFAULT_CEPH_PUB" root@"$ip"
}

# this function follows https://docs.ceph.com/en/latest/cephadm/host-management/
function enroll_hosts {
    # TODO: ADD LABELS to the host, otherwise it will get everythin (mon/mgr)
    # which is ok for an HCI solution
    for host in "${!HOSTS[@]}"; do
        echo "Processing host -> $host:${HOSTS[$host]}";
        ip=${HOSTS[$host]}
        distribute_keys "$ip"
        $SUDO $CEPHADM shell --fsid $FSID --config $CONFIG \
            --keyring $KEYRING -- ceph orch host add "$host $ip"
    done
    sleep "$SLEEP"
    # TODO: ADD DEVICES
}

function install_cephadm {
    curl -o cephadm https://raw.githubusercontent.com/ceph/ceph/squid/src/cephadm/cephadm.py
    $SUDO mv cephadm $TARGET_BIN
    $SUDO chmod +x $TARGET_BIN/cephadm
    echo "[INSTALL CEPHADM] cephadm is ready"
}

function rm_cluster {
    if ! [ -x "$CEPHADM" ]; then
        install_cephadm
        CEPHADM=${TARGET_BIN}/cephadm
    fi
    cluster=$(sudo cephadm ls | jq '.[]' | jq 'select(.name | test("^mon*")).fsid')
    if [ -n "$cluster" ]; then
        sudo cephadm rm-cluster --zap-osds --fsid "$FSID" --force
        echo "[CEPHADM] Cluster deleted"
    fi
}

function build_osds_from_list {
    for item in "${DEVICES[@]}"; do
        echo "Creating osd $item on node $HOSTNAME"
        $SUDO $CEPHADM shell --fsid $FSID --config $CONFIG \
            --keyring $KEYRING -- ceph orch daemon add osd "$HOSTNAME:$item"
    done
}

function configure_swift_rgw {
cat > "$RGW_CONF" <<-EOF
    ceph config set global rgw_keystone_url "$KEYSTONE_EP"
    ceph config set global rgw_keystone_verify_ssl false
    ceph config set global rgw_keystone_api_version 3
    ceph config set global rgw_keystone_accepted_roles "member, Member, admin"
    ceph config set global rgw_keystone_accepted_admin_roles "ResellerAdmin, swiftoperator"
    ceph config set global rgw_keystone_admin_domain default
    ceph config set global rgw_keystone_admin_project service
    ceph config set global rgw_keystone_admin_user "$RGW_USER"
    ceph config set global rgw_keystone_admin_password "$RGW_PASS"
    ceph config set global rgw_keystone_implicit_tenants true
    ceph config set global rgw_s3_auth_use_keystone true
    ceph config set global rgw_swift_versioning_enabled true
    ceph config set global rgw_swift_enforce_content_length true
    ceph config set global rgw_swift_account_in_url true
    ceph config set global rgw_trust_forwarded_https true
    ceph config set global rgw_max_attr_name_len 128
    ceph config set global rgw_max_attrs_num_in_req 90
    ceph config set global rgw_max_attr_size 1024
EOF
    $SUDO "$CEPHADM" shell -m "$RGW_CONF" --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- sh /mnt/"$RGW_CONF"
}

function rgw {
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph orch apply rgw default \
        "--placement=$HOSTNAME count:1" --port "$RGW_PORT"

    if [ "$RGW_INGRESS" -eq 1 ]; then
        echo "[CEPHADM] Deploy rgw.default Ingress Service"
        $SUDO "$CEPHADM" shell -m /tmp/"$RGW_INGRESS_SPEC" --fsid $FSID \
            --config $CONFIG --keyring $KEYRING -- ceph orch apply -i \
            /mnt/"$RGW_INGRESS_SPEC"
    fi
}

function mds {
    # Two pools are generated by this action
    # - $FSNAME.FSNAME.data
    # - $FSNAME.FSNAME.meta
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph orch apply mds "$FSNAME" \
        --placement="$HOSTNAME"
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph fs volume create "$FSNAME" \
        --placement="$HOSTNAME"
}

function nfs {
    echo "[CEPHADM] Deploy nfs.$FSNAME backend"
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph orch apply nfs \
        "$FSNAME" --placement="$HOSTNAME" --port "$NFS_PORT"
}

function process_services {
    for item in "${SERVICES[@]}"; do
        case "$item" in
            mds|MDS)
            echo "Deploying MDS on node $HOSTNAME"
            mds
            ;;
            nfs|NFS)
            echo "Deploying NFS on node $HOSTNAME"
            nfs
            NFS_CLIENT=1
            ;;
            rgw|RGW)
            echo "Deploying RGW on node $HOSTNAME"
            configure_swift_rgw
            rgw
            ;;
        esac
    done
}

# Pools are tied to their application, therefore the function
# iterates over the associative array that defines this relationship
# e.g. { 'volumes': 'rbd', 'manila_data': 'cephfs' }
function create_pools {

    [ "${#POOLS[@]}" -eq 0 ] && return;

    for pool in "${!POOLS[@]}"; do
        $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
            --keyring $KEYRING -- ceph osd pool create "$pool" $DEFAULT_PG_NUM \
            $DEFAULT_PGP_NUM replicated --autoscale-mode on

        # set the application to the pool (which also means rbd init the pool)
        $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
            --keyring $KEYRING -- ceph osd pool application enable "$pool" "${POOLS[$pool]}"
    done
}

function build_caps {
    local CAPS=""
    for pool in "${!POOLS[@]}"; do
        caps="allow rwx pool="$pool
        CAPS+=$caps,
    done
    echo "${CAPS::-1}"
}

function create_keys {

    local name=$1
    local caps
    local osd_caps

    if [ "${#POOLS[@]}" -eq 0 ]; then
        osd_caps="allow *"
    else
        caps=$(build_caps)
        osd_caps="allow class-read object_prefix rbd_children, $caps"
    fi

    $SUDO "$CEPHADM" shell -v "$KEY_EXPORT_DIR:$KEY_EXPORT_DIR" --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph auth get-or-create "$name" mon "allow r" osd "$osd_caps" \
        -o "$KEY_EXPORT_DIR/$name.keyring"
}

function cephadm_debug {
    if [ "$DEBUG" -eq 1 ]; then
        echo "[CEPHADM] Enabling Debug mode"
        $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
            --keyring $KEYRING -- ceph config set mgr mgr/cephadm/log_to_cluster_level debug
        echo "[CEPHADM] See debug logs running: ceph -W cephadm --watch-debug"
    fi
}

function check_cluster_status {
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph -s -f json-pretty
}

function export_spec {
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph orch ls --export > "$EXPORT"
    echo "Ceph cluster config exported: $EXPORT"
}

function dump_log {
    local daemon="$1"
    local num_lines=100

    echo "-------------------------"
    echo "dump daemon log: $daemon"
    echo "-------------------------"

    $SUDO $CEPHADM logs --fsid $FSID --name "$daemon" -- --no-pager -n $num_lines
}

function dump_all_logs {
    local daemons
    daemons=$($SUDO $CEPHADM ls | jq -r '.[] | select(.fsid == "'$FSID'").name')

    echo "Dumping logs for daemons: $daemons"
    for d in $daemons; do
        dump_log "$d"
    done
}

function set_container_images {
    if [ "$NFS_INGRESS" -eq 1 ]; then
        for image in "${!INGRESS_IMAGES[@]}"; do
            echo "[CEPHADM] Setting custom $image:${INGRESS_IMAGES[$image]} image"
            $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
                --keyring $KEYRING -- ceph config set mgr mgr/cephadm/container_image_$image quay.io/ceph/$image:${INGRESS_IMAGES[$image]}
        done
    fi
}

function prereq {
    for cmd in "${REQUIREMENTS[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Command $cmd not found"
            exit 1;
        fi
    done

}

function k8s_secret {
    KEY=$(cat /etc/ceph/ceph.client.openstack.keyring | base64 -w 0)
    CONF=$(cat /etc/ceph/ceph.conf | base64 -w 0)

cat <<EOF > "$HOME"/ceph_secret.yaml
apiVersion: v1
data:
  ceph.client.openstack.keyring: $KEY
  ceph.conf: $CONF
kind: Secret
metadata:
  name: ceph-conf-files
  namespace: openstack
type: Opaque
EOF
}


function install_export_cluster_resources_script {
    curl -o rook-create https://raw.githubusercontent.com/rook/rook/master/deploy/examples/create-external-cluster-resources.py
    $SUDO mv rook-create $TARGET_BIN
    $SUDO chmod +x $TARGET_BIN/rook-create
    echo "[INSTALL EXTERNAL_ROOK SCRIPTS] - Rook scripts are ready"
}

function rook_storage_cluster {

cat <<EOF > "$HOME"/rook-external.yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  name: $ROOK_CLUSTER_NAME
  namespace: $ROOK_NAMESPACE
spec:
  externalStorage:
    enable: true
  labelSelector: {}
EOF
}

function rook_storage_cluster_secret {
    ROOK_DUMP=$(cat "$HOME"/rook-details.json | base64 -w 0)
cat <<EOF > "$HOME"/rook-secret.yaml
apiVersion: v1
data:
  external_cluster_details: $ROOK_DUMP
kind: Secret
metadata:
  name: rook-external
  namespace: rook-ceph
type: Opaque
EOF
}

function external_rook {
    # 1. Make sure prometheus is enabled
    echo "Enable Ceph prometheus endpoint"
    $SUDO "$CEPHADM" shell -- ceph mgr module enable prometheus
    # 2. Download the create-external-cluster-resources.py script
    if [ -z "$EXPORT_CLUSTER_RESOURCES" ]; then
        install_export_cluster_resources_script
        EXPORT_CLUSTER_RESOURCES=${TARGET_BIN}/rook-create
    fi
    # 3. Run the python script
    echo "Extract Ceph cluster details"
    $SUDO python3 "$EXPORT_CLUSTER_RESOURCES" --ceph-conf /etc/ceph/ceph.conf \
        --keyring /etc/ceph/ceph.client.admin.keyring \
        --rbd-data-pool-name "$RBD_ROOK_POOL_NAME" \
        --run-as-user client.rook --format bash \
        --output "$HOME/$EXPORT_CLUSTER_RESOURCES_FILE"
    # 4. Patch the client.rook keyring to allow access to the rook pool
    $SUDO "$CEPHADM" shell -- ceph auth caps client.rook mds "allow *" mon "allow *" osd "allow rwx pool=$RBD_ROOK_POOL_NAME"
    # 5. Create the StorageCluster CR
    rook_storage_cluster
    # 6. Guide the user to the next step
    echo
    echo "External ROOK - Next steps:"
    echo "1. Copy the rook-env-vars script from $HOME/rook-env-vars.sh to the OpenShift client"
    echo "2. Get [import-external-cluster.sh](https://raw.githubusercontent.com/rook/rook/refs/heads/master/deploy/examples/import-external-cluster.sh) script"
    echo "3. On the OpenShift client node, run: source rook-env-vars.sh && ./import-external-cluster.sh"
    echo
}

function usage {
    # Display Help
    # ./deploy.sh -c quay.io/ceph/ceph:v16.2.6 -i 192.168.121.205 \
    #    -p volumes:rbd -p images -s rgw -s nfs -s mds -d /dev/ceph_vg/ceph_lv_data
    echo "Deploy a standalone Ceph cluster."
    echo
    echo "Syntax: $0 [-i <ip>][-p <pool><application>][-s <service>][-d </dev/device/path>]" 1>&2;
    echo "Options:"
    echo "d     Device path that is used to build OSD(s)."
    echo "h     Print this menu."
    echo "i     IP address where the mon(s)/mgr(s) daemons are deployed."
    echo "p     Pool list that are created (this option can be passed in the form pool:application)"
    echo "s     Services/Daemons that are added to the cluster."
    echo "t     Tear down the Ceph cluster."
    echo
    echo "Examples"
    echo
    echo "1. Deploy a minimal Ceph cluster using the specified IP"
    echo "> $0 -i 192.168.121.205"
    echo
    echo "2. Build the OSD(s) according to the specified paths"
    echo "> $0 -i IP -d /dev/ceph_vg/ceph_lv_data -d /dev/ceph_vg/ceph_lv_data1"
    echo
    echo "3. Deploy the Ceph cluster and add the specified pools"
    echo "> $0 -i IP -p volumes -p images:rbd"
    echo
    echo "4. Deploy the Ceph cluster and add the specified keys"
    echo "> $0 -i IP -k client.openstack -k client.manila -k client.glance"
    echo
    echo "5. Deploy the Ceph cluster and add the specified services"
    echo
    echo "> $0 -i IP -s rgw -s mds -s nfs"
    echo
    echo "6. Deploy the Ceph cluster using the given image:tag"
    echo "> $0 -i IP -c image:tag"
    echo
    echo "7. Tear Down the Ceph cluster"
    echo "> $0 -t"
    echo
    echo "A real use case Example"
    echo "$0 -c quay.io/ceph/ceph:v16.2.6 -i 192.168.121.205 -v 192.168.121.206 -p volumes:rbd -s rgw -s nfs -s mds -d /dev/vdb"
}

function preview {
    echo "---------"
    echo "SERVICES"
    for daemon in "${SERVICES[@]}"; do
        echo "* $daemon"
    done

    echo "---------"
    echo "POOLS"
    for key in "${!POOLS[@]}"; do
        echo "* $key:${POOLS[$key]}";
    done

    echo "---------"
    echo "KEYS"
    for kname in "${KEYS[@]}"; do
        echo "* $kname";
    done

    echo "---------"
    echo "DEVICES"
    for dev in "${DEVICES[@]}"; do
        echo "* $dev"
    done
    [ -z "$DEVICES" ] && echo "Using ALL available devices"

    echo "---------"
    echo MON IP Address: "$IP"
    echo "---------"
    echo "---------"
    echo VIP Addresses: "$VIP"
    echo "---------"
    echo "Container Image: $CONTAINER_IMAGE"
    echo "---------"
    if [ -z "$HOSTS" ]; then
        echo "---------"
        echo "ADDITIONAL HOSTS"
        for host in "${!HOSTS[@]}"; do
            echo "* $host:${HOSTS[$host]}"
        done
    fi
}

if [[ ${#} -eq 0 ]]; then
    usage
    exit 1
fi

## Process input parameters
while getopts "a:c:s:i:p:d:k:v:t" opt; do
    case $opt in
        a) curr_host=(${OPTARG//:/ })
            [ -z "${curr_host[1]}" ] && echo "-a: Malformed host" && exit -1
            # HOSTS input is provided in the form { HOSTNAME:IP }.
            # An associative array is built starting from this input.
            HOSTS[${curr_host[0]}]=${curr_host[1]}
            ;;
        c) CONTAINER_IMAGE="$OPTARG";;
        d) DEVICES+=("$OPTARG");;
        k) KEYS+=("$OPTARG");;
        i) IP="$OPTARG";;
        p) curr_pool=(${OPTARG//:/ })
            [ -z "${curr_pool[1]}" ] && curr_pool[1]=rbd
            # POOLS input is provided in the form { POOL:APPLICATION }.
            # An associative array is built starting from this input.
            POOLS[${curr_pool[0]}]=${curr_pool[1]}
            ;;
        s) SERVICES+=("$OPTARG");;
        t) rm_cluster
            exit 0
            ;;
        v) VIP="$OPTARG";;
        *) usage && exit -1
    esac
done
shift $((OPTIND -1))

prereq
preview
install_cephadm

if [ -z "$CEPHADM" ]; then
    CEPHADM=${TARGET_BIN}/cephadm
fi

cat <<EOF > "$ORIG_CONFIG"
[global]
  log to file = true
  osd_pool_default_size = 1
[mon]
  mon_warn_on_insecure_global_id_reclaim_allowed = False
  mon_warn_on_pool_no_redundancy = False
EOF

if [ "$DEV" -eq 1 ]; then
    mkdir -p "$WORKDIR"
    git clone https://github.com/ceph/ceph "$WORKDIR"
    SHARED_OPT="--shared_ceph_folder $WORKDIR"
fi

cluster=$(sudo cephadm ls | jq '.[]' | jq 'select(.name | test("^mon*")).fsid')
if [ -z "$cluster" ]; then
$SUDO $CEPHADM --image "$CONTAINER_IMAGE" \
      bootstrap \
      --fsid $FSID \
      --config "$ORIG_CONFIG" \
      --output-config $CONFIG \
      --output-keyring $KEYRING \
      --output-pub-ssh-key $CEPH_PUB_KEY \
      --allow-overwrite \
      --allow-fqdn-hostname \
      --skip-monitoring-stack \
      --skip-dashboard \
      --skip-firewalld \
      --single-host-defaults \
      --mon-ip $IP \
      $SHARED_OPT

test -e $CONFIG
test -e $KEYRING

# Wait cephadm backend to be operational
fi

sleep "$SLEEP"
cephadm_debug
# let's add some osds
if [ -z "$DEVICES" ]; then
    echo "Using ALL available devices"
    $SUDO $CEPHADM shell ceph orch apply osd --all-available-devices
else
    build_osds_from_list
fi


while [ "$ATTEMPTS" -ne 0 ]; do
    num_osds=$($SUDO $CEPHADM shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph -s -f json | jq '.osdmap | .num_up_osds')
    if [ "$num_osds" -ge "$MIN_OSDS" ]; then
        break;
    fi
    ATTEMPTS=$(("$ATTEMPTS" - 1))
    sleep 1
done
echo "[CEPHADM] OSD(s) deployed: $num_osds"

[ "$num_osds" -lt "$MIN_OSDS" ] && exit 255


if [ "$RGW_INGRESS" -eq 1 ]; then
cat > /tmp/$RGW_INGRESS_SPEC <<-EOF
service_type: ingress
service_id: rgw.default
service_name: ingress.rgw.default
placement:
    count: 1
spec:
    backend_service: rgw.default
    frontend_port: $RGW_INGRESS_FPORT
    monitor_port: $RGW_INGRESS_MPORT
    virtual_ip: $VIP/24"
EOF
fi


# add the provided pools
create_pools
for key_name in "${KEYS[@]}"; do
    echo "Processing key $key_name"
    create_keys "$key_name"
done

# customize container images (e.g., ingress)
set_container_images

# add more services
process_services
check_cluster_status

# get_ceph_cli
[ "${#HOSTS[@]}" -gt 0 ] && enroll_hosts

export_spec

# render a ceph client config file
echo "Dump the minimal ceph.conf"
cp $CONFIG $CLIENT_CONFIG

cat >> $CLIENT_CONFIG <<-EOF
[client.libvirt]
admin socket = /var/run/ceph/$cluster-$type.$id.$pid.$cctid.asok
log file = $RBD_CLIENT_LOG

EOF

if [ "$NFS_CLIENT" -eq 1 ]; then
cat >> $CLIENT_CONFIG <<-EOF
[$NFS_CLIENT_NAME]
client mount uid = 0
client mount gid = 0
log file = $NFS_CLIENT_LOG
admin socket = /var/run/ceph/\$cluster-\$type.\$id.\$pid.\$cctid.asok
keyring = $KEY_EXPORT_DIR/$NFS_CLIENT_NAME.keyring
EOF
echo "Client config exported: $CLIENT_CONFIG"
fi

if [ "$K8S" -eq 1 ]; then
k8s_secret
fi

if [ "$EXTERNAL_ROOK" -eq 1 ]; then
external_rook
fi
