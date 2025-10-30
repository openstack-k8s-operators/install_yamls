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
KPATCH_UPDATE=${KPATCH_UPDATE:-false}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-0.0.2}
OUTFILE=${OUTFILE:-csv.yaml}
TIMEOUT=${TIMEOUT:-1000s}
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

# The update_event.sh is created ci-framework update role.
update_event() {
    local event="${@:-Unknown Event}"
    local event_script="${UPDATE_ARTIFACT_DIR}/update_event.sh"
    if [ -e "${event_script}" ]; then
        "${event_script}" "${event}"
    fi
}

OPENSTACK_OPERATOR_CSV=$(oc get csv -n $OPERATOR_NAMESPACE -o name | grep openstack-operator)
OPENSTACK_VERSION_CR=$(oc get openstackversion -n $NAMESPACE -o name)

if [ "${FAKE_UPDATE}" != "false" ]; then
    oc get $OPENSTACK_OPERATOR_CSV -o yaml -n $OPERATOR_NAMESPACE  > $OUTFILE
    sed -i $OUTFILE -e "s|value: .*/$CONTAINERS_NAMESPACE/\(.*\)[@:].*|value: quay.io/$CONTAINERS_NAMESPACE/\1:$CONTAINERS_TARGET_TAG|g"
    OPENSTACK_DEPLOYED_VERSION=$(oc get -n $NAMESPACE $OPENSTACK_VERSION_CR --template={{.spec.targetVersion}})
    sed -i $OUTFILE -e "s|value: $OPENSTACK_DEPLOYED_VERSION|value: $OPENSTACK_VERSION|"

    update_event Applying Fake Update CR

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

update_event Patching the Openstack Version

oc patch $OPENSTACK_VERSION_CR  --type=merge  --patch-file openstackversionpatch.yaml

# wait for ovn update on control plane
oc wait $OPENSTACK_VERSION_CR --for=condition=MinorUpdateOVNControlplane --timeout=$TIMEOUT

update_event MinorUpdateOVNControlplane Completed

# start ovn update on data plane
nodes_with_ovn=()
# Get the names of all OpenStackDataPlaneNodeSet resources
openstackdataplanenodesets=$(oc get openstackdataplanenodeset -o custom-columns=NAME:.metadata.name,SERVICES:.spec.services --no-headers)

# Loop through each OpenStackDataPlaneNodeSet
while read -r node_name services; do
    # Check if 'ovn' is in the list of services
    for service in ${services[@]};do
        if [[ "$service" == *"ovn"* ]]; then
            nodes_with_ovn+=("- $node_name")
            break
        fi
    done
done <<< $openstackdataplanenodesets

DATAPLANE_DEPLOYMENT=edpm
OVN_NODE_SETS=$(printf '    %s\n' "${nodes_with_ovn[@]}")

cat <<EOF >edpm-deployment-ovn-update.yaml
apiVersion: dataplane.openstack.org/v1beta1
kind: OpenStackDataPlaneDeployment
metadata:
  name: $DATAPLANE_DEPLOYMENT-ovn-update
spec:
  nodeSets:
$OVN_NODE_SETS
  servicesOverride:
    - ovn
EOF

update_event Applying the OVN CRD

oc create -f edpm-deployment-ovn-update.yaml

oc get openstackdataplanedeployment ${DATAPLANE_DEPLOYMENT}-ovn-update -o yaml
# wait for ovn dataplane completes
oc wait $OPENSTACK_VERSION_CR  --for=condition=MinorUpdateOVNDataplane --timeout=$TIMEOUT
echo "MinorUpdateOVNDataplane completed"

update_event MinorUpdateOVNDataplane Completed

# wait for control plane update to complete
oc wait $OPENSTACK_VERSION_CR --for=condition=MinorUpdateControlplane --timeout=$TIMEOUT

update_event MinorUpdateControlplane Completed
echo "MinorUpdateControlplane completed"

# start data plane plane update for rest of edpm services
DATAPLANE_NODESETS=$(oc get openstackdataplanenodeset -o name | awk -F'/' '{print "    - "  $2}')

KPATCH_EXTRA_VAR=""
if [ "${KPATCH_UPDATE}" != "false" ]; then
    KPATCH_EXTRA_VAR='      edpm_update_enable_kpatch: "true"'
fi

ANSIBLE_EXTRA_VARS=""
if [ -n "${KPATCH_EXTRA_VAR}" ]; then
    ANSIBLE_EXTRA_VARS=' ansibleExtraVars:
    edpm_update_enable_kpatch: "true"
'
fi


cat <<EOF >edpm-deployment-update.yaml
apiVersion: dataplane.openstack.org/v1beta1
kind: OpenStackDataPlaneDeployment
metadata:
  name: $DATAPLANE_DEPLOYMENT-update
spec:
  nodeSets:
$DATAPLANE_NODESETS
  servicesOverride:
    - update
$ANSIBLE_EXTRA_VARS
EOF

update_event Applying the UPDATE CRD

oc create -f edpm-deployment-update.yaml

# wait for completion of minor update
oc wait $OPENSTACK_VERSION_CR --for=condition=MinorUpdateDataplane --timeout=$TIMEOUT
echo "MinorUpdate completed"
update_event MinorUpdateDataplane Completed

# check for the status of edpm update
oc get openstackdataplanedeployment ${DATAPLANE_DEPLOYMENT}-update -o yaml
