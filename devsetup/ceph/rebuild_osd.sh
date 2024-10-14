#!/bin/bash

index=${1:-"0"}
size=${2:-"7"}

function setup_loopback {
    major=$(grep loop /proc/devices | cut -c3)
    # setup loopback device
    sudo mknod /dev/loop"${index}" b "${major}" "${index}"
}

function build_ceph_osd {
    sudo dd if=/dev/zero of=/var/lib/ceph-osd-"${index}".img bs=1 count=0 seek="${size}"G
    sudo losetup /dev/loop"${index}" /var/lib/ceph-osd-"${index}".img
    sudo pvcreate  /dev/loop"${index}"
    sudo vgcreate ceph_vg_"${index}" /dev/loop"${index}"
    sudo lvcreate -n ceph_lv_data -l +100%FREE ceph_vg_"${index}"
}

function clean_ceph_osd {
    sudo lvremove --force /dev/ceph_vg/ceph_lv_data
    sudo vgremove --force ceph_vg
    sudo pvremove --force /dev/loop"${index}"
    sudo losetup -d /dev/loop"${index}"
    sudo rm -f /var/lib/ceph-osd-"${index}".img
    sudo partprobe
}

setup_loopback "${index}"
clean_ceph_osd "${index}"
build_ceph_osd "${index}"
