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

oc delete -n "${NAMESPACE}" job "cleanup-images-${NODE}" --ignore-not-found

cat << EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup-images-${NODE}
  namespace: ${NAMESPACE}
  labels:
    install-yamls.cleanup-images: ""
spec:
  ttlSecondsAfterFinished: 21600
  template:
    spec:
      containers:
      - name: cleanup
        image: bash:latest
        command: ["bash", "-c", "cp /usr/local/bin/cleanup-images.sh /host/tmp/cleanup-images.sh && chroot /host /bin/bash /tmp/cleanup-images.sh && rm -f /host/tmp/cleanup-images.sh"]
        securityContext:
          privileged: true
          allowPrivilegeEscalation: true
          runAsUser: 0
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
          - mountPath: /usr/local/bin/cleanup-images.sh
            name: cleanup-images
            readOnly: true
            subPath: cleanup-images.sh
          - name: host
            mountPath: /host
      nodeSelector:
        kubernetes.io/hostname: ${NODE}
      restartPolicy: Never
      securityContext:
        runAsUser: 0
      serviceAccount: cleanup-images
      volumes:
        - configMap:
            defaultMode: 493
            items:
              - key: cleanup-images.sh
                path: cleanup-images.sh
            name: cleanup-images
          name: cleanup-images
        - name: host
          hostPath:
            path: /
            type: Directory
  backoffLimit: 10
EOF

