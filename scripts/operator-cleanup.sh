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

if [ -z "$NAMESPACE" ]; then
  echo "Please set NAMESPACE"; exit 1
fi

if [ -z "$OPERATOR_NAME" ]; then
  echo "Please set OPERATOR_NAME"; exit 1
fi

CSV=$(oc get csv --no-headers -o custom-columns=":metadata.name" --ignore-not-found=true | grep $OPERATOR_NAME)

if [ -n "$CSV" ]; then
  oc delete -n ${NAMESPACE} csv ${CSV} --ignore-not-found=true
fi
oc delete -n ${NAMESPACE} subscription ${OPERATOR_NAME}-operator --ignore-not-found=true
oc delete -n ${NAMESPACE} catalogsource ${OPERATOR_NAME}-operator-index --ignore-not-found=true
