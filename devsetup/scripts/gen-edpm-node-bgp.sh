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
set -ex
export LIBVIRT_DEFAULT_URI=qemu:///system
# expect that the common.sh is in the same dir as the calling script
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CRC_POOL=${CRC_POOL:-"$HOME/.crc/machines/crc"}
OUTPUT_BASEDIR=${OUTPUT_BASEDIR:-"../out/edpm/"}

EDPM_SERVER_ROLE=${EDPM_SERVER_ROLE:-"compute"}

STANDALONE=${STANDALONE:-false}
EDPM_COMPUTE_SUFFIX=${1:-"0"}
EDPM_COMPUTE_NAME=${EDPM_COMPUTE_NAME:-"edpm-${EDPM_SERVER_ROLE}-${EDPM_COMPUTE_SUFFIX}"}
if [ ${STANDALONE} = "true" ]; then
    EDPM_COMPUTE_VCPUS=${EDPM_COMPUTE_VCPUS:-8}
    EDPM_COMPUTE_RAM=${EDPM_COMPUTE_RAM:-20}
    EDPM_COMPUTE_DISK_SIZE=${EDPM_COMPUTE_DISK_SIZE:-70}
fi
EDPM_COMPUTE_VCPUS=${EDPM_COMPUTE_VCPUS:-2}
EDPM_COMPUTE_RAM=${EDPM_COMPUTE_RAM:-4}
EDPM_COMPUTE_DISK_SIZE=${EDPM_COMPUTE_DISK_SIZE:-20}
EDPM_COMPUTE_NETWORK=${EDPM_COMPUTE_NETWORK:-default}
EDPM_COMPUTE_NETWORK_TYPE=${EDPM_COMPUTE_NETWORK_TYPE:-network}
EDPM_COMPUTE_NETWORK_IP=$(virsh net-dumpxml ${EDPM_COMPUTE_NETWORK} | xmllint --xpath 'string(/network/ip/@address)' -)
DATAPLANE_DNS_SERVER=${DATAPLANE_DNS_SERVER:-${EDPM_COMPUTE_NETWORK_IP}}
CENTOS_9_STREAM_URL=${CENTOS_9_STREAM_URL:-"https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"}
BASE_DISK_FILENAME=${BASE_DISK_FILENAME:-"centos-9-stream-base.qcow2"}

DISK_FILENAME=${DISK_FILENAME:-"edpm-${EDPM_SERVER_ROLE}-${EDPM_COMPUTE_SUFFIX}.qcow2"}
DISK_FILEPATH=${DISK_FILEPATH:-"${CRC_POOL}/${DISK_FILENAME}"}

SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-"${OUTPUT_BASEDIR}/ansibleee-ssh-key-id_rsa.pub"}
IP_ADRESS_SUFFIX=$((100+${EDPM_COMPUTE_SUFFIX}))

if [ ! -f ${SSH_PUBLIC_KEY} ]; then
    echo "${SSH_PUBLIC_KEY} is missing. Run gen-ansibleee-ssh-key.sh"
    exit 1
fi

if [ ! -d "${HOME}/.ssh" ]; then
    mkdir "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    restorecon -R "${HOME}/.ssh"
fi

for i in 0 1 2; do
    DISK_FILENAME="edpm-${EDPM_SERVER_ROLE}-$i.qcow2"
    DISK_FILEPATH="${CRC_POOL}/${DISK_FILENAME}"
    MAC_ADDRESS="$(echo -n 52:54:00; dd bs=1 count=3 if=/dev/random 2>/dev/null | hexdump -v -e '/1 "-%02X"' | tr '-' ':')"

    cat <<EOF >${OUTPUT_BASEDIR}/edpm-${EDPM_SERVER_ROLE}-$i.xml
<domain type='kvm'>
  <name>edpm-${EDPM_SERVER_ROLE}-$i</name>
  <memory unit='GiB'>${EDPM_COMPUTE_RAM}</memory>
  <currentMemory unit='GiB'>${EDPM_COMPUTE_RAM}</currentMemory>
  <memoryBacking>
    <source type='memfd'/>
    <access mode='shared'/>
  </memoryBacking>
  <vcpu placement='static'>${EDPM_COMPUTE_VCPUS}</vcpu>
  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <boot dev='hd'/>
    <bootmenu enable='no'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <feature policy='disable' name='rdrand'/>
  </cpu>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='${DISK_FILEPATH}'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x04' slot='0x00' function='0x0'/>
    </disk>
    <controller type='usb' index='0' model='qemu-xhci'>
      <address type='pci' domain='0x0000' bus='0x03' slot='0x00' function='0x0'/>
    </controller>
    <controller type='sata' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x1f' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pcie-root'/>
    <controller type='pci' index='1' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='1' port='0x10'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0' multifunction='on'/>
    </controller>
    <controller type='pci' index='2' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='2' port='0x11'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x1'/>
    </controller>
    <controller type='pci' index='3' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='3' port='0x12'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x2'/>
    </controller>
    <controller type='pci' index='4' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='4' port='0x13'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x3'/>
    </controller>
    <controller type='pci' index='5' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='5' port='0x14'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x4'/>
    </controller>
    <controller type='pci' index='6' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='6' port='0x15'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x5'/>
    </controller>
    <filesystem type='mount' accessmode='passthrough'>
      <driver type='virtiofs'/>
      <source dir='${HOME}'/>
      <target dir='dir0'/>
      <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
    </filesystem>
    <interface type='${EDPM_COMPUTE_NETWORK_TYPE}'>
      <mac address='${MAC_ADDRESS}'/>
      <source ${EDPM_COMPUTE_NETWORK_TYPE}='${EDPM_COMPUTE_NETWORK}'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x02' slot='0x00' function='0x0'/>
    </interface>
    <interface type='network'>
      <source network='l$[i+1]1-host-2'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
    </interface>
    <interface type='network'>
      <source network='l$[i+1]2-host-2'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x07' slot='0x00' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes'>
      <listen type='address'/>
    </graphics>
    <audio id='1' type='none'/>
    <video>
      <model type='cirrus' vram='16384' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x0'/>
    </video>
    <memballoon model='none'/>
    <rng model='virtio'>
      <backend model='random'>/dev/urandom</backend>
      <address type='pci' domain='0x0000' bus='0x05' slot='0x00' function='0x0'/>
    </rng>
  </devices>
</domain>
EOF

done

for i in 0 1 2; do
    cat <<EOF >${OUTPUT_BASEDIR}/edpm-${EDPM_SERVER_ROLE}-$i-firstboot.sh
growpart /dev/vda 1
xfs_growfs /

# create cloud-admin user
sudo useradd cloud-admin
echo 'cloud-admin     	ALL = (ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/cloud-admin
sudo chown root:root /etc/sudoers.d/cloud-admin
sudo chmod 0660 /etc/sudoers.d/cloud-admin

# don't kill processes after ssh logout
sudo loginctl enable-linger cloud-admin

# initialize authorized keys from root
if [ ! -e /home/cloud-admin/.ssh/authorized_keys ]; then
	sudo mkdir -p /home/cloud-admin/.ssh
	sudo chmod 0700 /home/cloud-admin/.ssh
	sudo cp /root/.ssh/authorized_keys /home/cloud-admin/.ssh/authorized_keys
	sudo chown -R cloud-admin: /home/cloud-admin/.ssh
	sudo chmod 0600 /home/cloud-admin/.ssh/authorized_keys
fi

# Set network for current session
nmcli device modify eth0 ipv4.addresses 192.168.122.10$i/24 ipv4.method manual

# Set network to survive reboots
echo IPADDR=192.168.122.10$i >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo PREFIX=24 >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo DNS1=192.168.122.1 >> /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i s/dhcp/none/g /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i /PERSISTENT_DHCLIENT/d /etc/sysconfig/network-scripts/ifcfg-eth0

systemctl restart NetworkManager
ip r add default via 192.168.122.1

# Remove stale artifacts that are auto-generated during EDPM deployment
rm -f /etc/nvme/hostid /etc/nvme/hostnqn

EOF
done


for i in 0 1 2; do
    DISK_FILENAME="edpm-${EDPM_SERVER_ROLE}-$i.qcow2"
    DISK_FILEPATH="${CRC_POOL}/${DISK_FILENAME}"

    if [ ! -f ${DISK_FILEPATH} ]; then
        if [ ! -f ${CRC_POOL}/centos-9-stream-base.qcow2 ]; then
            pushd ${CRC_POOL}
            curl -L -k ${CENTOS_9_STREAM_URL} -o centos-9-stream-base.qcow2
            popd
        fi
        qemu-img create -o backing_file=${CRC_POOL}/centos-9-stream-base.qcow2,backing_fmt=qcow2 -f qcow2 "${DISK_FILEPATH}" "${EDPM_COMPUTE_DISK_SIZE}G"
        if [[ ! -e /usr/bin/virt-customize ]]; then
            sudo dnf -y install /usr/bin/virt-customize
        fi
        VIRT_HOST_KNOWN_HOSTS=$(ssh-keyscan 192.168.130.1)
        virt-customize -a ${DISK_FILEPATH} \
            --root-password password:12345678 \
            --hostname edpm-${EDPM_SERVER_ROLE}-$i \
            --firstboot ${OUTPUT_BASEDIR}/edpm-${EDPM_SERVER_ROLE}-$i-firstboot.sh \
            --run-command "systemctl disable cloud-init cloud-config cloud-final cloud-init-local" \
            --run-command "echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/99-root-login.conf" \
            --run-command "mkdir -p /root/.ssh; chmod 0700 /root/.ssh" \
            --run-command "ssh-keygen -f /root/.ssh/id_rsa -N ''" \
            --run-command "echo \"${VIRT_HOST_KNOWN_HOSTS}\" >> /root/.ssh/known_hosts" \
            --ssh-inject root:string:"$(cat $SSH_PUBLIC_KEY)" \
            --selinux-relabel || rm -f ${DISK_FILEPATH}
        if [ ! -f ${DISK_FILEPATH} ]; then
            exit 1
        fi
    fi
done


for i in 0 1 2; do
    if ! virsh domuuid edpm-${EDPM_SERVER_ROLE}-$i; then
        virsh define "${OUTPUT_BASEDIR}/edpm-${EDPM_SERVER_ROLE}-$i.xml"
    else
        echo "edpm-${EDPM_SERVER_ROLE}-$i-0 already defined in libvirt, not redefining."
    fi
    if [ "$(virsh domstate edpm-${EDPM_SERVER_ROLE}-$i)" != "running" ]; then
        virsh start edpm-${EDPM_SERVER_ROLE}-$i
    else
        echo "edpm-${EDPM_SERVER_ROLE}-$i already running."
    fi
done
