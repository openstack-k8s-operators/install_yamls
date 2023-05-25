#!/bin/bash
#
# Copyright 2023 Red Hat Inc.
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

#
# Wait for an operator's controller-manager deployment to become fully available
#

set -x

if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

if [ -z "$OPERATOR_NAME" ]; then
    echo "Please set OPERATOR_NAME"; exit 1
fi

# wait for controller-manager deployment to appear
timeout 300s bash -c 'until [ "$(oc get deployment -l openstack.org/operator-name=${OPERATOR_NAME} -n ${NAMESPACE} -o name)" != "" ]; do sleep 1; done'

# wait for controller-manager deployment to reach available state
oc wait deployment -l openstack.org/operator-name=${OPERATOR_NAME} -n ${NAMESPACE} --for condition=Available --timeout=300s
