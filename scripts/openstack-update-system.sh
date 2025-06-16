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

CI_INVENTORY="${HOME}/ci-framework-data/artifacts/zuul_inventory.yml"
DATAPLANE_DEPLOYMENT=edpm
TIMEOUT=${TIMEOUT:-1000s}
UPDATE_ARTIFACT_DIR="${UPDATE_ARTIFACT_DIR:-${HOME}/ci-framework-data/tests/update}"


if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi


# The update_event.sh is created ci-framework update role.
update_event() {
    local event="${@:-Unknown Event}"
    local event_script="${UPDATE_ARTIFACT_DIR}/update_event.sh"
    if [ -e "${event_script}" ]; then
        "${event_script}" "${event}"
    fi
}

oc project $NAMESPACE

# start data plane system update
DATAPLANE_NODESETS=$(oc get openstackdataplanenodeset -o name | awk -F'/' '{print "    - "  $2}')

cat <<EOF >edpm-deployment-update-system.yaml
apiVersion: dataplane.openstack.org/v1beta1
kind: OpenStackDataPlaneDeployment
metadata:
  name: $DATAPLANE_DEPLOYMENT-update-system
spec:
  nodeSets:
$DATAPLANE_NODESETS
  servicesOverride:
    - update-system
EOF

update_event Applying the EDPM UPDATE-SYSTEM deployment CR

oc create -f edpm-deployment-update-system.yaml

# wait for completion of minor update
oc wait OpenStackDataPlaneDeployment/${DATAPLANE_DEPLOYMENT}-update-system --for=condition=DeploymentReady --timeout=$TIMEOUT

update_event EDPM Update System Completed

# check for the status of edpm update-system
oc get openstackdataplanedeployment ${DATAPLANE_DEPLOYMENT}-update-system -o yaml
