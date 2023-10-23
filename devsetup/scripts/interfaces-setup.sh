#!/bin/bash
# set -x

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit
fi

if [ -n "$BGP" ]; then
    # We cannot add PCI slots with the VM running
    sudo virsh destroy crc

    cat << EOF > /tmp/pci1.xml
<controller type='pci' index='7' model='pcie-root-port'>
  <model name='pcie-root-port'/>
  <target chassis='7' port='0x16'/>
  <alias name='pci.7'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x6'/>
</controller>
EOF

    cat << EOF > /tmp/pci2.xml
<controller type='pci' index='8' model='pcie-root-port'>
  <model name='pcie-root-port'/>
  <target chassis='8' port='0x17'/>
  <alias name='pci.8'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x7'/>
</controller>
EOF

    sudo virsh detach-device crc --file /tmp/pci1.xml --persistent || true
    sleep 1
    sudo virsh detach-device crc --file /tmp/pci2.xml --persistent || true
    sleep 10

    sudo virsh attach-device crc --file /tmp/pci1.xml --persistent
    sleep 1
    sudo virsh attach-device crc --file /tmp/pci2.xml --persistent
    sleep 10

    sudo virsh start crc
    # wait for the VM to be up
    sleep 240
fi

MAC_ADDRESS=$(echo -n 52:54:00; dd bs=1 count=3 if=/dev/random 2>/dev/null | hexdump -v -e '/1 "-%02X"' | tr '-' ':')
virsh --connect=qemu:///system net-update default add-last ip-dhcp-host --xml "<host mac='$MAC_ADDRESS' name='crc' ip='$DEFAULT_NETWORK_IP'/>" --config --live
virsh --connect=qemu:///system attach-interface crc --source default --type network --model virtio --mac $MAC_ADDRESS --config --persistent

sleep 5
if [ -n "$BGP" ]; then
    virsh --connect=qemu:///system attach-interface crc --source l41-host-1 --type network --model virtio --mac $BGP_NIC_1_MAC --config --persistent
    sleep 5
    virsh --connect=qemu:///system attach-interface crc --source l42-host-1 --type network --model virtio --mac $BGP_NIC_2_MAC --config --persistent
    sleep 5
fi
