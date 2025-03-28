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
OPERATION=${1:-"create"}

cat << EOF | oc apply -f -
apiVersion: v1
data:
  create-storage.sh: |
    #!/bin/bash

    for i in \`seq -w -s ' ' \${PV_NUM}\`; do
      echo "creating dir /mnt/openstack/pv\$i on host"
      mkdir -p /mnt/nodeMnt/openstack/pv\$i
    done
  delete-storage.sh: |
    #!/bin/bash

    for i in \`seq -w -s ' ' \${PV_NUM}\`; do
      echo "deleting dir /mnt/openstack/pv\$i on host"
      rm -rf /mnt/nodeMnt/openstack/pv\$i
    done
kind: ConfigMap
metadata:
  name: crc-storage
  namespace: ${NAMESPACE}
EOF

cat << EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: crc-storage
  namespace: ${NAMESPACE}
EOF

cat << EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: crc-storage-role
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
  name: crc-storage-rolebinding
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: crc-storage-role
subjects:
- kind: ServiceAccount
  name: crc-storage
  namespace: ${NAMESPACE}
EOF
