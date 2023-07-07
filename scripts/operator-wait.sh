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

TIMEOUT=${TIMEOUT:-300s}
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

if [ -z "${OPERATOR_NAMESPACE}" ]; then
    echo "Please set OPERATOR_NAMESPACE"; exit 1
fi

if [ -z "$OPERATOR_NAME" ]; then
    echo "Please set OPERATOR_NAME"; exit 1
fi

if [ "$OPERATOR_NAME" = "rabbitmq" ]; then
    OPERATOR_NAME="rabbitmq-cluster"
fi

pushd $SCRIPTPATH
timeout ${TIMEOUT} bash -c 'until [ "$(bash ./get-operator-status.sh)" == "Succeeded" ]; do sleep 1; done'
rc=$?
popd
exit $rc
