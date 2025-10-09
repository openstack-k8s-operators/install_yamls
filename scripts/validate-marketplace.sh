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
set -x

if [ -z "${TIMEOUT}" ]; then
    echo "Please set TIMEOUT"; exit 1
fi

OPERATOR_NAMESPACE=openshift-marketplace

# Similar part was done in CI Framework CRC jobs
# https://review.rdoproject.org/cgit/config/tree/playbooks/crc/files/ensure_services_up.sh
not_running_pods=$(oc get pods --no-headers -n ${OPERATOR_NAMESPACE} 2>/dev/null | grep -viE 'running|completed')
if [ -z "$not_running_pods" ]; then
    echo "All $OPERATOR_NAMESPACE pods seems to me fine"
else
    # Workaround for problematic openshift-marketplace
    # More info: https://github.com/crc-org/crc/issues/4109#issuecomment-2042497411
    oc delete pods --all -n "${OPERATOR_NAMESPACE}"
    oc wait pod --for=delete -n "$OPERATOR_NAMESPACE" -l olm.managed --timeout=${TIMEOUT}
    oc wait pod -n ${OPERATOR_NAMESPACE} -l olm.managed --for condition=Ready
fi

OPERATORS="openshift-cert-manager-operator kubernetes-nmstate-operator metallb-operator"

for operator in $OPERATORS; do
    n=0
    retries="${1:-20}"  # Number of retries with a default value of 20
    while true; do
        oc get packagemanifests -n ${OPERATOR_NAMESPACE} | grep $operator
        if [ $? -eq 0 ]; then
            break
        fi
        n=$((n+1))
        if (( n >= retries )); then
            echo "Failed to get packagemanifest for operator $operator. Aborting"
            exit 1
        fi
        sleep 10
    done
done
