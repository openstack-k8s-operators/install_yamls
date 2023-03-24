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
set -x

function rm_operator {

    local NAMESPACE="$1"
    local OPERATOR="$2"

    local CSV=$(oc get csv --no-headers -o custom-columns=":metadata.name" --ignore-not-found=true | grep $OPERATOR)

    if [ -n "$CSV" ]; then
      oc delete -n ${NAMESPACE} csv ${CSV} --ignore-not-found=true
    fi
    oc delete -n ${NAMESPACE} subscription ${OPERATOR_NAME}-operator --ignore-not-found=true
    oc delete -n ${NAMESPACE} catalogsource ${OPERATOR_NAME}-operator-index --ignore-not-found=true
}


if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

if [ -z "$OPERATOR_NAME" ]; then
    echo "Please set OPERATOR_NAME"; exit 1
fi

OPERATORS=()

if [[ "$OPERATOR_NAME" == "openstack" ]]; then
    # List all the operators in the ${NAMESPACE}
    OPERATORS=$(oc get subs -n ${NAMESPACE} -o jsonpath='{range .items[*]}{.spec.name}{"\n"}{end}')
else
    OPERATORS=($OPERATOR_NAME)
fi

# For each operator delete the associated resources (csv/subs/catalogsource)
for operator in $OPERATORS; do
    rm_operator $NAMESPACE $operator
done
