#!/bin/bash
#
# Copyright 2026 Red Hat Inc.
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

if [ -z "${OPERATOR_NAMESPACE}" ]; then
    echo "Please set OPERATOR_NAMESPACE"; exit 1
fi
if [ -z "${APPROVE_CSV}" ]; then
    set +x
    echo "ERROR: APPROVE_CSV is not set. Set it to the CSV whose InstallPlan you want to approve," >&2
    echo "       e.g. APPROVE_CSV=openstack-operator.v19.0.1 make openstack_approve_installplan" >&2
    echo "InstallPlans awaiting approval in ${OPERATOR_NAMESPACE}:" >&2
    oc get installplan -n "${OPERATOR_NAMESPACE}" \
        -o custom-columns=NAME:.metadata.name,CSV:.spec.clusterServiceVersionNames,APPROVED:.spec.approved >&2 || true
    exit 1
fi

TIMEOUT=${TIMEOUT:-300s}

# Name of the newest pending InstallPlan that targets APPROVE_CSV. Empty if
# none exists yet. Filters approved==false and phase!=Failed to skip stale
# plans from prior runs.
find_installplan() {
    oc get installplan -n "${OPERATOR_NAMESPACE}" -o json | \
        jq -r --arg csv "${APPROVE_CSV}" \
        '[.items[] | select(.spec.clusterServiceVersionNames[]? == $csv) | select(.spec.approved == false) | select(.status.phase != "Failed")]
         | sort_by(.metadata.creationTimestamp) | last | .metadata.name // empty'
}
export -f find_installplan
export OPERATOR_NAMESPACE APPROVE_CSV

# Wait for OLM to generate the (Manual) InstallPlan for the requested CSV.
timeout "${TIMEOUT}" bash -c 'until [ -n "$(find_installplan)" ]; do sleep 2; done' || {
    echo "ERROR: no unapproved InstallPlan for CSV ${APPROVE_CSV} appeared within ${TIMEOUT}. Existing InstallPlans:"
    oc get installplan -n "${OPERATOR_NAMESPACE}" -o custom-columns=NAME:.metadata.name,CSVS:.spec.clusterServiceVersionNames,APPROVED:.spec.approved
    exit 1
}

IP=$(find_installplan)
oc patch installplan "${IP}" -n "${OPERATOR_NAMESPACE}" --type merge -p '{"spec":{"approved":true}}'

# Wait for the CSV to finish installing, failing fast if it enters a bad phase.
timeout "${TIMEOUT}" bash -c '
    until phase=$(oc get csv "${APPROVE_CSV}" -n "${OPERATOR_NAMESPACE}" -o jsonpath="{.status.phase}" 2>/dev/null); [ "${phase}" = "Succeeded" ]; do
        case "${phase}" in
            Failed) echo "CSV ${APPROVE_CSV} entered Failed phase"; exit 1;;
        esac
        sleep 5
    done' || {
    echo "ERROR: CSV ${APPROVE_CSV} did not reach Succeeded within ${TIMEOUT} (last phase: $(oc get csv "${APPROVE_CSV}" -n "${OPERATOR_NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null))"
    exit 1
}
