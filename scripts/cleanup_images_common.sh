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

cat << EOF | oc apply -f -
apiVersion: v1
data:
  cleanup-images.sh: |
    #!/bin/bash

    # Exit immediately if a command fails
    set -e

    echo "--- Finding openstack-operator images ---"
    IMAGE_IDS=\$(/usr/bin/crictl images | grep "openstack-operator" | awk '{print \$3}')

    if [ -z "\$IMAGE_IDS" ]; then
      echo "No matching images found on this node."
      exit 0
    fi

    for attempt in {1..5}; do
      echo "Attempt \$attempt: Trying to remove images..."
      # Try to remove images, capture output to check for errors
      REMOVE_OUTPUT=\$(/usr/bin/crictl rmi \$IMAGE_IDS 2>&1 || true)
      echo "\$REMOVE_OUTPUT"

      # Check if any images remain
      REMAINING=\$(/usr/bin/crictl images | grep "openstack-operator" | awk '{print \$3}' || true)

      if [ -z "\$REMAINING" ]; then
        echo "Success: All images removed."
        exit 0
      fi

      if [ \$attempt -lt 5 ]; then
        echo "Some images still in use. Checking which containers..."
        # Extract container IDs from error messages and show container details
        CONTAINER_IDS=\$(echo "\$REMOVE_OUTPUT" | grep -oP 'image used by \K[a-f0-9]{64}' || true)
        for cid in \$CONTAINER_IDS; do
          echo "Container using image: \$cid"
          /usr/bin/crictl inspect \$cid | grep -E '"name"|"state"|"image"' || true
          POD_ID=\$(/usr/bin/crictl inspect \$cid | grep -oP '"podSandboxId": "\K[^"]+' || true)
          if [ -n "\$POD_ID" ]; then
            echo "Pod details:"
            /usr/bin/crictl inspectp \$POD_ID | grep -E '"name"|"namespace"|"state"' || true
          fi
        done
        echo "Retrying in 10 seconds..."
        sleep 10
        # Update IMAGE_IDS to only the remaining images
        IMAGE_IDS=\$REMAINING
      fi
    done

    echo "Error: Could not remove all images after 5 attempts. Remaining images:"
    /usr/bin/crictl images | grep "openstack-operator" || true
    exit 1
kind: ConfigMap
metadata:
  name: cleanup-images
  namespace: ${NAMESPACE}
EOF

cat << EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cleanup-images
  namespace: ${NAMESPACE}
EOF

cat << EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cleanup-images-role
  namespace: ${NAMESPACE}
rules:
- apiGroups:
  - security.openshift.io
  resourceNames:
  - anyuid
  - privileged
  resources:
  - securitycontextconstraints
  verbs:
  - use
- apiGroups:
  - ""
  resources:
  - pods
  - jobs
  verbs:
  - create
  - get
  - list
  - watch
  - update
  - patch
  - delete
EOF

cat << EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cleanup-images-rolebinding
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cleanup-images-role
subjects:
- kind: ServiceAccount
  name: cleanup-images
  namespace: ${NAMESPACE}
EOF

