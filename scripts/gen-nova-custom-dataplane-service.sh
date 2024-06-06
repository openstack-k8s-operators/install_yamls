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
# Create the nova-extra-config CM based on the provided config file
cat <<EOF >>kustomization.yaml
configMapGenerator:
- name: nova-extra-config
  files:
    - 25-nova-extra.conf=${EDPM_EXTRA_NOVA_CONFIG_FILE}
  options:
    disableNameSuffixHash: true
EOF
fi
