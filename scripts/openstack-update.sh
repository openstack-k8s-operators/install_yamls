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
CONTAINERS_NAMESPACE=${CONTAINERS_NAMESPACE:-podified-antelope-centos9}
CONTAINERS_TARGET_TAG=${CONTAINERS_TARGET_TAG:-current-podified}
FAKE_UPDATE=${FAKE_UPDATE:-false}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-0.0.2}
OUTFILE=${OUTFILE:-csv.yaml}
TIMEOUT=${TIMEOUT:-600s}
CI_INVENTORY="${HOME}/ci-framework-data/artifacts/zuul_inventory.yml"
UPDATE_ARTIFACT_DIR="${UPDATE_ARTIFACT_DIR:-${HOME}/ci-framework-data/tests/update}"


if [ -z "$OPERATOR_NAMESPACE" ]; then
    echo "Please set OPERATOR_NAMESPACE"; exit 1
fi
if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

if [ -e "${CI_INVENTORY}" ]; then
    RUN_FROM_CI=YES
fi

BASE_DIR="${UPDATE_ARTIFACT_DIR}"
if [ -e "${BASE_DIR}" ]; then
    BASE_DIR="${BASE_DIR}/"
else
    BASE_DIR=""                 # current directory
fi

function get_current_compute_state {
    local stage="${1:-}"
    file_pre="${BASE_DIR}${stage:+${stage}-}"

    if [ -e "${CI_INVENTORY}" ]; then
        echo "Collecting compute state ${stage:+for $stage }in ${BASE_DIR:-${PWD}}"

        # Collect all running containers an all compute nodes in ~/ci-framework-data/tests/update/ by default.
        ansible -i "${CI_INVENTORY}" -m shell -a \
                "sudo podman ps -q --filter 'status=running' | xargs -I {} sudo podman inspect --format {% raw %} '{{.Name}} {{.Config.Image}} {{.State.StartedAt}}' {% endraw %} {}|sort" computes | \
            awk -vfile_pre="${file_pre}" 'BEGIN {tp=strftime("%Y%m%d%H%M%S")} /^compute/ {if (s != "") {close(s)}; s = "containers-" $1 "_" tp ".txt"; next;}; s {print > file_pre s} '
        # Collect packages list an all compute nodes in ~/ci-framework-data/tests/update/ by default.
        ansible -i "${CI_INVENTORY}" -m shell -a \
                "sudo dnf list installed | sort" computes | \
            awk -vfile_pre="${file_pre}" 'BEGIN {tp=strftime("%Y%m%d%H%M%S")} /^compute/ {if (s != "") {close(s)}; s = "packages-" $1 "_" tp ".txt"; next;}; s {print > file_pre s} '
    fi
}

function get_current_pod_state {
    local stage="${1:-}"
    file_pre="${BASE_DIR}${stage:+${stage}-}"

    echo "Collecting pod state ${stage:+for $stage }in ${BASE_DIR:-${PWD}}"

    local openstack_state_file="${file_pre}pods_os_state_$(date +%Y%m%d_%H%M%S).tsv"
    local os_operator_state_file="${file_pre}pods_os_op_state_$(date +%Y%m%d_%H%M%S).tsv"
    oc get pods -n "${OPERATOR_NAMESPACE}" -o json | jq -r '.items[] | select(.status.phase == "Running") | . as $pod | .status.containerStatuses[] | [$pod.metadata.name, $pod.status.startTime, .image, .state.running.startedAt ] | @tsv' > $os_operator_state_file

    oc get pods -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.status.phase == "Running") | . as $pod | .status.containerStatuses[] | [$pod.metadata.name, $pod.status.startTime, .image, .state.running.startedAt ] | @tsv' > $openstack_state_file
}

function get_current_state {
    local stage="${1:-}"
    get_current_compute_state "${stage}"
    get_current_pod_state "${stage}"
}

get_current_state "01_before_update"

OPENSTACK_OPERATOR_CSV=$(oc get csv -n $OPERATOR_NAMESPACE -o name | grep openstack-operator)
OPENSTACK_VERSION_CR=$(oc get openstackversion -n $NAMESPACE -o name)

if [ "${FAKE_UPDATE}" != "false" ]; then
    oc get $OPENSTACK_OPERATOR_CSV -o yaml -n $OPERATOR_NAMESPACE  > $OUTFILE
    sed -i $OUTFILE -e "s|value: .*/$CONTAINERS_NAMESPACE/\(.*\)[@:].*|value: quay.io/$CONTAINERS_NAMESPACE/\1:$CONTAINERS_TARGET_TAG|g"
    OPENSTACK_DEPLOYED_VERSION=$(oc get -n $NAMESPACE $OPENSTACK_VERSION_CR --template={{.spec.targetVersion}})
    sed -i $OUTFILE -e "s|value: $OPENSTACK_DEPLOYED_VERSION|value: $OPENSTACK_VERSION|"

    oc apply -f $OUTFILE
fi

oc project $NAMESPACE
# wait until openstackVersion cr completes reconcile, status.availableVersion should be the same as VERSION
oc wait $OPENSTACK_VERSION_CR --for=jsonpath='{.status.availableVersion}'=$OPENSTACK_VERSION --timeout=$TIMEOUT


OPENSTACK_DEPLOYED_VERSION=$(oc get $OPENSTACK_VERSION_CR --template={{.spec.targetVersion}})

cat <<EOF >openstackversionpatch.yaml
    "spec": {
      "targetVersion": "$OPENSTACK_VERSION"
      }
EOF

oc patch $OPENSTACK_VERSION_CR  --type=merge  --patch-file openstackversionpatch.yaml

# wait for ovn update on control plane
oc wait $OPENSTACK_VERSION_CR --for=condition=MinorUpdateOVNControlplane --timeout=$TIMEOUT

get_current_state "02_after_ovn_controlplane_update"

# start ovn update on data plane
DATAPLANE_NODESET=$(oc get openstackdataplanenodeset -o name | awk -F'/' '{print "    - "  $2}')
DATAPLANE_DEPLOYMENT=$(oc get openstackdataplanedeployment -o name | awk -F'/' '{print $2; exit}')

cat <<EOF >edpm-deployment-ovn-update.yaml
apiVersion: dataplane.openstack.org/v1beta1
kind: OpenStackDataPlaneDeployment
metadata:
  name: $DATAPLANE_DEPLOYMENT-ovn-update
spec:
  nodeSets:
$DATAPLANE_NODESET
  servicesOverride:
    - ovn
EOF

oc create -f edpm-deployment-ovn-update.yaml

oc get openstackdataplanedeployment
# wait for ovn dataplane completes
oc wait $OPENSTACK_VERSION_CR  --for=condition=MinorUpdateOVNDataplane --timeout=$TIMEOUT
echo "MinorUpdateOVNDataplane completed"

get_current_state "03_after_ovn_dataplane_update"

# wait for control plane update to complete
oc wait $OPENSTACK_VERSION_CR --for=condition=MinorUpdateControlplane --timeout=$TIMEOUT
echo "MinorUpdateControlplane completed"

get_current_state "04_after_controlplane_update"

# start data plane plane update for rest of edpm services
cat <<EOF >edpm-deployment-update.yaml
apiVersion: dataplane.openstack.org/v1beta1
kind: OpenStackDataPlaneDeployment
metadata:
  name: $DATAPLANE_DEPLOYMENT-update
spec:
  nodeSets:
$DATAPLANE_NODESET
  servicesOverride:
    - update
EOF

oc create -f edpm-deployment-update.yaml

# wait for completion of minor update
oc wait $OPENSTACK_VERSION_CR --for=condition=MinorUpdateDataplane --timeout=$TIMEOUT
echo "MinorUpdate completed"

get_current_state "05_after_update"

# check for the status of edpm update
oc get openstackdataplanedeployment ${DATAPLANE_DEPLOYMENT}-update -o yaml
