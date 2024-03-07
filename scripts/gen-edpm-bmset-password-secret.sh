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

function create_bmset_password_secret {
cat <<EOF | oc create -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: baremetalset-password-secret
  namespace: ${NAMESPACE}
type: Opaque
data:
  NodeRootPassword: ${EDPM_ROOT_PASSWORD}
EOF
}

oc get secret baremetalset-password-secret -n ${NAMESPACE} || create_bmset_password_secret
