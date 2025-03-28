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

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
. "${SCRIPTPATH}/storage_common.sh"

PV_NUM=${PV_NUM:-12}
TIMEOUT=${TIMEOUT:-300s}

NODE_NAMES=$(oc get node -o template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' -l node-role.kubernetes.io/worker)
if [ -z "$NODE_NAMES" ]; then
    echo "Unable to determine node name with 'oc' command."
    exit 1
fi
for node in $NODE_NAMES; do
    . "${SCRIPTPATH}/storage_apply.sh" "${node}" "delete"
done

oc wait job -n "${NAMESPACE}" -l install-yamls.crc.storage --for condition=Complete --timeout "${TIMEOUT}"
