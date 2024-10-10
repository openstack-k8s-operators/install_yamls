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
declare -a DISKS=("vdb")
DISK_SIZE=${DISK_SIZE:-100}
DISK_PATH=${DISK_PATH:-$HOME/.crc}
DOMAIN=${DOMAIN:-crc}

mkdir -p "$DISK_PATH"

function create_disk {
    for disk in "${DISKS[@]}"; do
        qemu-img create -f raw "$DISK_PATH"/"$disk" "${DISK_SIZE}"G
    done
}

function attach_disk {
    for disk in "${DISKS[@]}"; do
        sudo virsh attach-disk "$DOMAIN" "$DISK_PATH"/"$disk" "$disk" --targetbus virtio --persistent
    done
}

create_disk
attach_disk
