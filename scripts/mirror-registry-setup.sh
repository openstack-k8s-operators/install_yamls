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
if [ -z "${MIRROR_NAMESPACE}" ]; then
    echo "Please set MIRROR_NAMESPACE"; exit 1
fi
if [ -z "${OUT_DIR}" ]; then
    echo "Please set OUT_DIR"; exit 1
fi

OPERATOR_INDEX_IMAGE=${OPERATOR_INDEX_IMAGE:-"quay.io/openstack-k8s-operators/openstack-operator-index:latest"}

# registry.redhat.io images require auth - block them and use quay.io equivalents
# Format: "registry.redhat.io/path=quay.io/path"
REDHAT_TO_QUAY_REPLACEMENTS=${REDHAT_TO_QUAY_REPLACEMENTS:-"
registry.redhat.io/ubi9/httpd-24=quay.io/ubi9/httpd-24
"}


mkdir -p ${OUT_DIR}

# Check oc-mirror is available
OC_MIRROR_BIN=${OC_MIRROR_BIN:-"oc-mirror"}
if ! command -v ${OC_MIRROR_BIN} &> /dev/null; then
    # Try in ~/bin
    if [ -f "${HOME}/bin/oc-mirror" ]; then
        OC_MIRROR_BIN="${HOME}/bin/oc-mirror"
    else
        echo "ERROR: 'oc-mirror' not found."
        echo "Install via: cd devsetup && make download_tools"
        exit 1
    fi
fi

# Verify the binary is executable
if ! [ -x "$(command -v ${OC_MIRROR_BIN})" ]; then
    echo "ERROR: oc-mirror is not executable. Check installation."
    exit 1
fi

REGISTRY_TOKEN=$(oc whoami -t)

# Create mirror namespace and allow image pulls
oc create namespace ${MIRROR_NAMESPACE} --dry-run=client -o yaml | oc apply -f -
oc policy add-role-to-group system:image-puller system:serviceaccounts -n ${MIRROR_NAMESPACE} || true
oc policy add-role-to-group system:image-puller system:authenticated -n ${MIRROR_NAMESPACE} || true
oc policy add-role-to-group system:image-puller system:unauthenticated -n ${MIRROR_NAMESPACE} || true

# Configure insecure registry if requested (default: true for mirror_registry, false for mirror_registry_secure)
MIRROR_INSECURE=${MIRROR_INSECURE:-true}
if [ "${MIRROR_INSECURE}" = "true" ]; then
    CURRENT_INSECURE=$(oc get image.config.openshift.io/cluster -o jsonpath='{.spec.registrySources.insecureRegistries}' 2>/dev/null || echo "")
    if ! echo "${CURRENT_INSECURE}" | grep -q "${MIRROR_REGISTRY_HOST}"; then
        oc patch image.config.openshift.io/cluster --type=merge -p "{\"spec\":{\"registrySources\":{\"insecureRegistries\":[\"${MIRROR_REGISTRY_HOST}\"]}}}"
        sleep 10
        oc wait mcp master --for condition=Updated --timeout=300s || true
    fi
fi

# Get operator index digest
OPERATOR_INDEX_DIGEST=$(skopeo inspect --tls-verify=false "docker://${OPERATOR_INDEX_IMAGE}" 2>/dev/null | jq -r '.Digest // empty')
if [ -z "${OPERATOR_INDEX_DIGEST}" ]; then
    OPERATOR_INDEX_DIGEST=$(skopeo inspect "docker://${OPERATOR_INDEX_IMAGE}" 2>/dev/null | jq -r '.Digest // empty')
fi

# Create ImageSetConfiguration
cat > ${OUT_DIR}/imageset-config.yaml <<EOF
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v2alpha1
mirror:
  operators:
    - catalog: ${OPERATOR_INDEX_IMAGE}
      full: true
      targetCatalog: ${MIRROR_NAMESPACE}/openstack-operator-index
      targetTag: latest
EOF

# Add blocked images (registry.redhat.io images we'll replace with quay.io)
BLOCKED_IMAGES=""
REPLACEMENT_IMAGES=""
for replacement in ${REDHAT_TO_QUAY_REPLACEMENTS}; do
    [ -z "$replacement" ] && continue
    src=$(echo "$replacement" | cut -d'=' -f1)
    dst=$(echo "$replacement" | cut -d'=' -f2)
    [ -n "$src" ] && BLOCKED_IMAGES="${BLOCKED_IMAGES} ${src}"
    [ -n "$dst" ] && REPLACEMENT_IMAGES="${REPLACEMENT_IMAGES} ${dst}"
done

if [ -n "${BLOCKED_IMAGES}" ]; then
    echo "  blockedImages:" >> ${OUT_DIR}/imageset-config.yaml
    for img in ${BLOCKED_IMAGES}; do
        [ -z "$img" ] && continue
        echo "    - name: ${img}" >> ${OUT_DIR}/imageset-config.yaml
    done
fi

# Add replacement images as additionalImages
if [ -n "${REPLACEMENT_IMAGES}" ]; then
    echo "  additionalImages:" >> ${OUT_DIR}/imageset-config.yaml
    for img in ${REPLACEMENT_IMAGES}; do
        [ -z "$img" ] && continue
        echo "    - name: ${img}" >> ${OUT_DIR}/imageset-config.yaml
    done
fi

# Setup authentication for mirror registry
AUTH_DIR="${XDG_RUNTIME_DIR:-/tmp}/containers"
mkdir -p ${AUTH_DIR}
MIRROR_REGISTRY_AUTH=$(echo -n "kubeadmin:${REGISTRY_TOKEN}" | base64 -w0)

rm -f ${AUTH_DIR}/auth.json
cat > ${AUTH_DIR}/auth.json <<EOF
{
  "auths": {
    "${MIRROR_REGISTRY_HOST}": {
      "auth": "${MIRROR_REGISTRY_AUTH}"
    }
  }
}
EOF

# Wait for API server to be ready
oc wait --for=condition=Available deployment/apiserver -n openshift-apiserver --timeout=120s || true

# Run oc-mirror v2
# --max-nested-paths 2: OpenShift internal registry only supports <namespace>/<name> format
# --parallel-images 1: Reduce parallelism to avoid overwhelming CRC's API server
# --retry-times/--retry-delay: Handle transient API server errors
# --dest-tls-verify=false: oc-mirror runs locally and doesn't have cluster CA trust
#   (secure mode configures CA for cluster image pulls, not for oc-mirror push)
${OC_MIRROR_BIN} --v2 \
    -c ${OUT_DIR}/imageset-config.yaml \
    --workspace file://${OUT_DIR}/oc-mirror-workspace \
    --dest-tls-verify=false \
    --max-nested-paths 2 \
    --parallel-images 1 \
    --retry-times 5 \
    --retry-delay 10s \
    docker://${MIRROR_REGISTRY_HOST}/${MIRROR_NAMESPACE}

MIRROR_EXIT_CODE=$?

# Check for errors
if [ ${MIRROR_EXIT_CODE} -ne 0 ]; then
    exit ${MIRROR_EXIT_CODE}
fi

# Copy and apply generated resources
CLUSTER_RESOURCES_DIR="${OUT_DIR}/oc-mirror-workspace/working-dir/cluster-resources"
if [ -d "${CLUSTER_RESOURCES_DIR}" ]; then
    cp ${CLUSTER_RESOURCES_DIR}/*.yaml ${OUT_DIR}/ 2>/dev/null || true

    # Apply IDMS/ITMS
    IDMS_FILE=$(ls ${CLUSTER_RESOURCES_DIR}/idms*.yaml 2>/dev/null | head -1)
    ITMS_FILE=$(ls ${CLUSTER_RESOURCES_DIR}/itms*.yaml 2>/dev/null | head -1)
    [ -n "${IDMS_FILE}" ] && oc apply -f ${IDMS_FILE}
    [ -n "${ITMS_FILE}" ] && oc apply -f ${ITMS_FILE}
fi

# Create IDMS for registry.redhat.io -> quay.io replacements
if [ -n "${REDHAT_TO_QUAY_REPLACEMENTS}" ]; then
    cat > ${OUT_DIR}/idms-redhat-replacements.yaml <<EOF
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: redhat-to-quay-replacements
spec:
  imageDigestMirrors:
EOF
    for replacement in ${REDHAT_TO_QUAY_REPLACEMENTS}; do
        [ -z "$replacement" ] && continue
        src=$(echo "$replacement" | cut -d'=' -f1)
        dst=$(echo "$replacement" | cut -d'=' -f2)
        [ -z "$src" ] || [ -z "$dst" ] && continue
        dst_path=$(echo "$dst" | cut -d'/' -f2-)
        cat >> ${OUT_DIR}/idms-redhat-replacements.yaml <<EOF
    - source: ${src}
      mirrors:
        - ${MIRROR_REGISTRY_HOST}/${dst_path}
      mirrorSourcePolicy: NeverContactSource
EOF
    done
    oc apply -f ${OUT_DIR}/idms-redhat-replacements.yaml
fi

# Set mirrorSourcePolicy: NeverContactSource on all IDMS entries
# This ensures images are pulled ONLY from the mirror (true disconnected testing)
for idms_name in $(oc get imagedigestmirrorset -o name 2>/dev/null || true); do
    CURRENT_POLICY=$(oc get ${idms_name} -o jsonpath='{.spec.imageDigestMirrors[0].mirrorSourcePolicy}' 2>/dev/null || echo "")
    if [ "${CURRENT_POLICY}" != "NeverContactSource" ]; then
        MIRROR_COUNT=$(oc get ${idms_name} -o jsonpath='{.spec.imageDigestMirrors}' | jq 'length')
        PATCH="["
        for ((i=0; i<MIRROR_COUNT; i++)); do
            [ $i -gt 0 ] && PATCH="${PATCH},"
            PATCH="${PATCH}{\"op\":\"add\",\"path\":\"/spec/imageDigestMirrors/$i/mirrorSourcePolicy\",\"value\":\"NeverContactSource\"}"
        done
        PATCH="${PATCH}]"
        oc patch ${idms_name} --type=json -p "${PATCH}"
    fi
done

# Find the mirrored catalog image
MIRRORED_CATALOG=$(oc get imagestreams -n ${MIRROR_NAMESPACE} -o name 2>/dev/null | grep -i "operator-index" | head -1 | cut -d'/' -f2)
if [ -n "${MIRRORED_CATALOG}" ]; then
    MIRRORED_CATALOG_URL="${MIRROR_REGISTRY_HOST}/${MIRROR_NAMESPACE}/${MIRRORED_CATALOG}"
else
    MIRRORED_CATALOG_URL="${MIRROR_REGISTRY_HOST}/${MIRROR_NAMESPACE}/openstack-operator-index"
fi

# Show usage
if [ -n "${OPERATOR_INDEX_DIGEST}" ]; then
    echo "make openstack OPENSTACK_IMG=${MIRRORED_CATALOG_URL}@${OPERATOR_INDEX_DIGEST}"
else
    echo "make openstack OPENSTACK_IMG=${MIRRORED_CATALOG_URL}:latest"
fi
