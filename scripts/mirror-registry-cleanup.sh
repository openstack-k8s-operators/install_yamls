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

if [ -z "${MIRROR_NAMESPACE}" ]; then
    echo "Please set MIRROR_NAMESPACE"; exit 1
fi

# Delete IDMS/ITMS - oc-mirror generated and custom
oc delete imagedigestmirrorset openstack-mirror --ignore-not-found=true
oc delete imagetagmirrorset openstack-mirror --ignore-not-found=true
oc delete imagedigestmirrorset redhat-to-quay-replacements --ignore-not-found=true
for idms in $(oc get imagedigestmirrorset -o name 2>/dev/null | grep -E 'oc-mirror|openstack' || true); do
    oc delete ${idms} --ignore-not-found=true
done
for itms in $(oc get imagetagmirrorset -o name 2>/dev/null | grep -E 'oc-mirror|openstack' || true); do
    oc delete ${itms} --ignore-not-found=true
done

# Reset registry route to remove custom TLS configuration
oc patch route default-route -n openshift-image-registry --type=json \
    -p='[{"op": "remove", "path": "/spec/tls/certificate"},{"op": "remove", "path": "/spec/tls/key"}]' 2>/dev/null || true

# Delete CA configmap and reset additionalTrustedCA
oc delete configmap mirror-registry-ca -n openshift-config --ignore-not-found=true
oc patch image.config.openshift.io/cluster \
    --patch '{"spec":{"additionalTrustedCA":{"name":""}}}' \
    --type=merge || true

# Remove insecure registry config
oc patch image.config.openshift.io/cluster \
    --patch '{"spec":{"registrySources":null}}' \
    --type=merge || true

# Delete namespace
oc delete namespace ${MIRROR_NAMESPACE} --ignore-not-found=true
