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

oc get pods -n ${OPERATOR_NAMESPACE} | grep "CrashLoopBackOff"
if [ $? -eq 0 ]; then
    oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
    oc wait pod --for=delete -n ${OPERATOR_NAMESPACE} -l olm.managed --timeout=${TIMEOUT}
    oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": false}]'
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
