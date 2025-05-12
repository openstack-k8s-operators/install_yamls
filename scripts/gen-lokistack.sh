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

if [ -z "${DEPLOY_DIR}" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

if [ -z "${NAMESPACE}" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

if [ -z "${STORAGE_CLASS}" ]; then
    echo "Please set STORAGE_CLASS"; exit 1
fi

if [ -z "${SIZE}" ]; then
    echo "Please set SIZE"; exit 1
fi

if [ -z "${MODE}" ]; then
    echo "Please set MODE"; exit 1
fi

echo DEPLOY_DIR ${DEPLOY_DIR}
echo NAMESPACE ${NAMESPACE}
echo SIZE ${SIZE}
echo MODE ${MODE}

cat > ${DEPLOY_DIR}/lokisecret.yaml <<EOF_CAT
---
apiVersion: v1
kind: Secret
metadata:
  name: loki-s3
  namespace: ${NAMESPACE}
stringData:
  access_key_id: QUtJQUlPU0ZPRE5ON0VYQU1QTEUK
  access_key_secret: d0phbHJYVXRuRkVNSS9LN01ERU5HL2JQeFJmaUNZRVhBTVBMRUtFWQo=
  bucketnames: s3-bucket-name
  endpoint: https://s3.eu-central-1.amazonaws.com
  region: eu-central-1
EOF_CAT

cat > ${DEPLOY_DIR}/lokistack.yaml <<EOF_CAT
---
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: loki
  namespace: ${NAMESPACE}
spec:
  size: ${SIZE}
  storage:
    schemas:
    - version: v12
      effectiveDate: '2022-06-01'
    secret:
      name: loki-s3
      type: s3
  storageClassName: ${STORAGE_CLASS}
  tenants:
    mode: ${MODE}
EOF_CAT
