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

if [ -z "$STORAGE_CLASS" ]; then
    echo "Please set STORAGE_CLASS"; exit 1
fi

if [ ! -d out/crc ]; then
    mkdir -p out/crc
fi
PV_NUM=${PV_NUM:-12}

NODE_NAMES=$(oc get node -o name -l node-role.kubernetes.io/worker | sed -e 's|node/||' | head -c-1 | tr '\n' ',')
if [ -z "$NODE_NAMES" ]; then
    echo "Unable to determine node name with 'oc' command."
    exit 1
fi

cat > out/crc/storage.yaml <<EOF_CAT
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ${STORAGE_CLASS}
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF_CAT

for i in `seq -w $PV_NUM`; do
cat >> out/crc/storage.yaml <<EOF_CAT
---
kind: PersistentVolume
apiVersion: v1
metadata:
  name: "$(sed -e 's/^"//' -e 's/"$//' <<<"${STORAGE_CLASS}")$i"
  annotations:
    pv.kubernetes.io/provisioned-by: crc-devsetup
spec:
  storageClassName: ${STORAGE_CLASS}
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
    - ReadOnlyMany
  persistentVolumeReclaimPolicy: Delete
  local:
    path: "/mnt/openstack/pv$i"
    type: DirectoryOrCreate
  volumeMode: Filesystem
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [${NODE_NAMES}]
EOF_CAT
done
