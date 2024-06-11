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

set -e

if [ "${EDPM_SERVER_ROLE}" == "compute" ]; then
# Create a nova-custom service with a reference to nova-extra-config CM
cat <<EOF >>kustomization.yaml
- target:
    kind: OpenStackDataPlaneService
    name: nova
  patch: |-
    - op: replace
      path: /metadata/name
      value: nova-custom
    - op: add
      path: /spec/configMaps
      value:
        - nova-extra-config
EOF

# Create the nova-extra-config CM based on the provided config file
cat <<EOF >>kustomization.yaml
configMapGenerator:
- name: nova-extra-config
  files:
    - 25-nova-extra.conf=${EDPM_EXTRA_NOVA_CONFIG_FILE}
  options:
    disableNameSuffixHash: true
EOF

# Replace the nova service in the nodeset with the new nova-custom service
#
# NOTE(gibi): This is hard to do with kustomize as it only allows
# list item replacemnet by index and not by value, but we cannot
# be sure that the index is not changing in the future by
# adding more services or splitting existing services.
# The kustozmization would be something like:
#     - op: replace
#      path: /spec/services/11
#      value: nova-custom
#
# So we do a replace by value with yq (assuming golang implementation of yq)
yq -i '(.spec.services[] | select(. == "nova")) |= "nova-custom"' dataplane.yaml
fi
