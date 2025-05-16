#!/bin/bash
set -x

# expect that the common.sh is in the same dir as the calling script
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
. "${SCRIPTPATH}"/common.sh --source-only

# Some defaults
DISK_SIZE=${DISK_SIZE:-100}
TARGET_DIR=${TARGET_DIR:=$HOME/.crc/machines/crc}
OCP_API=${OCP_API:-"192.168.130.11"}
REQUIRE_RESTART=${REQUIRE_RESTART:-1}
# if this parameter is set to 1, a LVM_CLUSTER CR is created and applied,
# otherwise, only the operator is deployed through OLM
LVMS_CLUSTER_CR=${LVMS_CLUSTER_CR:-0}
LVMS_NAMESPACE=${LVMS_NAMESPACE:-openshift-storage}

# Timeout defaults
API_TIMEOUT=100
CSV_TIMEOUT=300
TIME=5
# If CRC == 0 the device creation and attach is skipped (e.g. we use a SNO or
# an environment where the disk is already available
# If CRC == 1 the device are created and attached to CRC
CRC=${CRC:-1}

# Disk map in the form <disk_name>:<size>
declare -A DEVICES
DEVICES["vdb"]=100

if [ ! -d "${DEPLOY_DIR}" ]; then
    mkdir -p "${DEPLOY_DIR}"
fi

pushd "${DEPLOY_DIR}"

# Add a device passed as input and attach it to crc
function add_device {
    local disk_name="$1"
    local size="${2-$DISK_SIZE}"
    if [[ ! -e "${TARGET_DIR}/$disk_name" ]]; then
        echo "Creating Device $disk_name:$size"
        sudo -S qemu-img create -f raw "${TARGET_DIR}/${disk_name}" "${size}"G
    fi
    # this condition might fail if the disk is attached but not present in the
    # virsh dumpxml output
    if [[ -z "$(sudo virsh dumpxml crc | grep "$disk_name")" ]]; then
        # Attach the disk to the crc VM: it requires reboot
        echo "Attaching disk $disk_name to crc"
        sudo virsh attach-disk crc "${TARGET_DIR}/${disk_name}" "${disk_name}" --config
    fi
}

# Restart CRC if REQUIRE_RESTART=1: this is required
# to make the new devices available
function restart_crc {
    sudo virsh destroy crc
    sleep "$TIME"
    sudo virsh start crc
    status=""
    while [ -z $status ]; do
        if curl -k https://"${OCP_API}":6443; then
            status="ok";
        else
            sleep "$TIME"
        fi
    done
}

# Deploy the LVMS operator based on the official OLM deploy samples
function lvms_operator_kustomize {
cat <<EOF >kustomization.yaml
resources:
- https://github.com/openshift/lvm-operator/config/olm-deploy

patches:
- patch: |-
    - op: remove
      path: /spec/channel
    - op: replace
      path: /spec/source
      value: redhat-operators
    - op: replace
      path: /spec/sourceNamespace
      value: openshift-marketplace
  target:
    kind: Subscription
    name: lvms-operator
EOF

# apply the LVMS operator
oc kustomize "${DEPLOY_DIR}" | oc apply -f -
}

# By default we're going to use all the available
# disks provided by crc
function lvms_cluster_deploy {
cat <<EOF >lvms_cluster.yaml
apiVersion: lvm.topolvm.io/v1alpha1
kind: LVMCluster
metadata:
  name: lvmcluster
  namespace: $LVMS_NAMESPACE
spec:
  storage:
    deviceClasses:
      - name: vg1
        fstype: ext4
        default: true
        thinPoolConfig:
          name: thin-pool-1
          sizePercent: 90
          overprovisionRatio: 10
        deviceSelector:
          paths:
EOF
for disk in "${!DEVICES[@]}"; do
    echo "          - /dev/$disk"
done >> lvms_cluster.yaml

# apply the resulting CR
oc apply -f "${DEPLOY_DIR}"/lvms_cluster.yaml
}


# Patch openshift-storage namespace to get the right annotations
function patch_lvms_ns {
cat <<EOF >lvms_ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-storage
  annotations:
    workload.openshift.io/allowed: "management"
    openshift.io/sa.scc.uid-range: "1000090000/10000"
    openshift.io/sa.scc.mcs: "s0:c26,c5"
  labels:
    pod-security.kubernetes.io/enforce: "privileged"
    openshift.io/cluster-monitoring: "false"
EOF

# apply the LVMS ns
oc apply -f "${DEPLOY_DIR}"/lvms_ns.yaml
}

function get_csv_version {
    until [[ "Succeeded" == "$(oc -n "$LVMS_NAMESPACE" get csv -o json | jq -r '.items[] | select(.metadata.name | contains("lvms-operator")) | .status.phase' 2>/dev/null)" ]]; do
        sleep $TIME
        (( CSV_TIMEOUT-- ))
        [[ "$CSV_TIMEOUT" -eq 0 ]] && exit 1
    done
    oc -n openshift-storage get csv -o json | jq -r '.items[] | select(.metadata.name | contains("lvms-operator")) | .spec.version'
}

function patch_csv_metrics {
    version=$(get_csv_version)
    oc -n "$LVMS_NAMESPACE" patch csv -n "$LVMS_NAMESPACE" lvms-operator.v$version \
        --type=json -p="[{'op': 'remove', 'path': '/spec/install/spec/deployments/0/spec/template/spec/containers/0/volumeMounts/1'}]"
}

# wait for OCP API after a crc restart
function wait_for_ocp_api {
    echo "Wait for the OCP API to be fully available"
    until oc get clusterversion &> /dev/null; do
        sleep 1
        echo -n .
        (( API_TIMEOUT-- ))
        [[ "$API_TIMEOUT" -eq 0 ]] && exit 1
    done
    echo
}

# deploy the LVMS operator and, if CRC is used, add the devices passed
# as input
function lvms_operator_deploy {
    if [ "$CRC" -eq 1 ]; then
        # Add the defined devices to crc
        for key in "${!DEVICES[@]}"; do
            add_device "$key" "${DEVICES[$key]}"
        done
        if [[ $REQUIRE_RESTART -eq 1 ]]; then
            restart_crc
        fi
        wait_for_ocp_api
    fi
    # Deploy LVMS operator
    lvms_operator_kustomize
}

# main LVMS flow - it consists in the following actions:
# 1. create and attach disks to the CRC VM
# 2. restart CRC and wait for the ocp API
# 3a. deploy the LVMS operator
# 3b. deploy the LVMS Cluster CR (only after 3a is done)
function main {
    if [[ "$LVMS_CLUSTER_CR" -eq 1 ]]; then
        # Build and deploy LVMS Cluster CR
        lvms_cluster_deploy
    else
        # Deploy LVMS operator
        lvms_operator_deploy
        # Patch the openshift-storage namespace with the
        # expected annotations and labels.
        echo "Rolling out the lvms-operator"
        patch_lvms_ns
        # In addition, to avoid waiting >=5 minutes for a missing
        # metric-cert secret that results in a volumeMount that
        # doesn't exist, we remove it
        patch_csv_metrics
    fi
}

main
