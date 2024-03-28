#!/bin/bash
# set -x

export VIRSH_DEFAULT_CONNECT_URI=qemu:///system
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
EDPM_COMPUTE_SUFFIX=${1:-"0"}
EDPM_COMPUTE_NETWORK=${EDPM_COMPUTE_NETWORK:-default}
STANDALONE_VM=${STANDALONE_VM:-"true"}
if [[ ${STANDALONE_VM} == "true" ]]; then
    EDPM_COMPUTE_NETWORK_IP=$(virsh net-dumpxml ${EDPM_COMPUTE_NETWORK} | xmllint --xpath 'string(/network/ip/@address)' -)
fi
IP_ADRESS_SUFFIX=${IP_ADRESS_SUFFIX:-"$((100+${EDPM_COMPUTE_SUFFIX}))"}
IP=${IP:-"${EDPM_COMPUTE_NETWORK_IP%.*}.${IP_ADRESS_SUFFIX}"}
OUTPUT_DIR=${OUTPUT_DIR:-"${SCRIPTPATH}/../../out/edpm/"}
SSH_KEY_FILE=${SSH_KEY_FILE:-"${OUTPUT_DIR}/ansibleee-ssh-key-id_rsa"}
SSH_OPT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY_FILE"

virsh snapshot-revert --domain edpm-compute-${EDPM_COMPUTE_SUFFIX} --snapshotname clean
ssh $SSH_OPT root@$IP systemctl stop chronyd ';' chronyd -q  \'pool pool.ntp.org iburst\' ';' systemctl start chronyd
ssh $SSH_OPT root@$IP test -f /etc/systemd/system/ceph-osd-losetup.service '&&' systemctl restart ceph-osd-losetup.service '&&' test -b /dev/vg2/data-lv2
