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

if [ -z "${MIRROR_REGISTRY_HOST}" ]; then
    echo "Please set MIRROR_REGISTRY_HOST"; exit 1
fi
if [ -z "${OUT_DIR}" ]; then
    echo "Please set OUT_DIR"; exit 1
fi

mkdir -p ${OUT_DIR}

REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-openshift-image-registry}"
CA_NAME="${CA_NAME:-mirror-registry-ca}"
CERT_DAYS="${CERT_DAYS:-365}"

# Extract just the hostname (remove port if present)
REGISTRY_HOSTNAME=$(echo ${MIRROR_REGISTRY_HOST} | cut -d: -f1)

# Generate self-signed CA
openssl genrsa -out ${OUT_DIR}/ca.key 4096
openssl req -x509 -new -nodes -key ${OUT_DIR}/ca.key -sha256 -days ${CERT_DAYS} \
    -out ${OUT_DIR}/ca.crt \
    -subj "/CN=${CA_NAME}/O=Mirror Registry Test"

# Generate server certificate
openssl genrsa -out ${OUT_DIR}/server.key 4096

cat > ${OUT_DIR}/server.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${REGISTRY_HOSTNAME}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${REGISTRY_HOSTNAME}
DNS.2 = image-registry.openshift-image-registry.svc
DNS.3 = image-registry.openshift-image-registry.svc.cluster.local
EOF

openssl req -new -key ${OUT_DIR}/server.key -out ${OUT_DIR}/server.csr -config ${OUT_DIR}/server.conf
openssl x509 -req -in ${OUT_DIR}/server.csr -CA ${OUT_DIR}/ca.crt -CAkey ${OUT_DIR}/ca.key \
    -CAcreateserial -out ${OUT_DIR}/server.crt -days ${CERT_DAYS} -sha256 \
    -extfile ${OUT_DIR}/server.conf -extensions v3_req

# Update the route with the custom certificate
# Build patch JSON in a file to avoid printing cert/key in console
set +x
jq -n \
    --arg cert "$(cat ${OUT_DIR}/server.crt)" \
    --arg key "$(cat ${OUT_DIR}/server.key)" \
    '{"spec":{"tls":{"termination":"reencrypt","certificate":$cert,"key":$key}}}' \
    > ${OUT_DIR}/route-patch.json
oc patch route default-route -n ${REGISTRY_NAMESPACE} --type=merge --patch-file=${OUT_DIR}/route-patch.json
rm -f ${OUT_DIR}/route-patch.json
set -x

# Add CA to cluster trust
REGISTRY_KEY=$(echo ${MIRROR_REGISTRY_HOST} | sed 's/:/../')
oc create configmap mirror-registry-ca \
    --from-file=${REGISTRY_KEY}=${OUT_DIR}/ca.crt \
    -n openshift-config \
    --dry-run=client -o yaml | oc apply -f -

oc patch image.config.openshift.io/cluster \
    --patch '{"spec":{"additionalTrustedCA":{"name":"mirror-registry-ca"}}}' \
    --type=merge

# Wait for MCP to update
oc wait mcp master --for condition=Updating=False --timeout=300s || true
oc wait mcp master --for condition=Updated --timeout=300s || true

# Wait for registry pod to be ready (it restarts when TLS changes)
oc rollout status deployment/image-registry -n openshift-image-registry --timeout=300s || true

# Wait for image-registry cluster operator to be stable
oc wait co/image-registry --for condition=Available --timeout=120s || true
oc wait co/image-registry --for condition=Progressing=False --timeout=120s || true
oc wait co/image-registry --for condition=Degraded=False --timeout=120s || true

# Wait for openshift-apiserver to be stable
oc wait co/openshift-apiserver --for condition=Available --timeout=120s || true
oc wait co/openshift-apiserver --for condition=Progressing=False --timeout=120s || true

# Test registry is responsive
REGISTRY_TOKEN=$(oc whoami -t)
for i in {1..30}; do
    if curl -sk -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer ${REGISTRY_TOKEN}" \
        "https://${MIRROR_REGISTRY_HOST}/v2/" | grep -q "200\|401"; then
        break
    fi
    sleep 5
done
