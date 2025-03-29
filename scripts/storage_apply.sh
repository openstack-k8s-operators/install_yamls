#!/bin/bash
#
# Copyright 2025 Red Hat Inc.
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

NODE=${1:-"crc"}
OPERATION=${2:-"create"}

oc delete -n "${NAMESPACE}" job "crc-storage-${NODE}" --ignore-not-found

cat << EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: crc-storage-${NODE}
  namespace: ${NAMESPACE}
  labels:
    install-yamls.crc.storage: ""
spec:
  template:
    spec:
      containers:
      - name: storage
        image: quay.io/openstack-k8s-operators/bash:latest
        env:
          - name: PV_NUM
            value: "${PV_NUM}"
        command: ["bash"]
        args: ["/usr/local/bin/crc-storage.sh"]
        securityContext:
          privileged: true
          allowPrivilegeEscalation: true
          runAsUser: 0
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
          - mountPath: /usr/local/bin/crc-storage.sh
            name: crc-storage
            readOnly: true
            subPath: ${OPERATION}-storage.sh
          - name: node-mnt
            mountPath: /mnt/nodeMnt
      nodeSelector:
        kubernetes.io/hostname: ${NODE}
        node-role.kubernetes.io/worker: ""
      restartPolicy: Never
      securityContext:
        runAsUser: 0
      serviceAccount: crc-storage
      volumes:
        - configMap:
            defaultMode: 493
            items:
              - key: ${OPERATION}-storage.sh
                path: ${OPERATION}-storage.sh
            name: crc-storage
          name: crc-storage
        - name: node-mnt
          hostPath:
            path: /mnt
            type: Directory
  backoffLimit: 10
EOF
