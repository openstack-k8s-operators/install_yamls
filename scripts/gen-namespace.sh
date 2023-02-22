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

if [ -z "$OUT" ]; then
    echo "Please set OUT"; exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

OUT_DIR=${OUT}/${NAMESPACE}

if [ ! -d ${OUT_DIR} ]; then
    mkdir -p ${OUT_DIR}
fi

# can share this for all the operators, won't get re-applied if it already exists
cat > ${OUT_DIR}/namespace.yaml <<EOF_CAT
apiVersion: v1
kind: Namespace
metadata:
    name: ${NAMESPACE}
    labels:
      pod-security.kubernetes.io/enforce: privileged
      security.openshift.io/scc.podSecurityLabelSync: "false"
EOF_CAT
