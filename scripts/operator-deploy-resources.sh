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
set -x

#
# Retry the creation of a particular operator's CR resources for ~2 minutes.
# This will help smooth-out potentially transient errors resulting from:
#   1. OLM being slow to install CRDs
#   2. OLM installing webhook configuration quickly, but the operator's
#      controller-manager pod being slow to reach the ready state 
#

if [ -z "$DEPLOY_DIR" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

NEXT_WAIT_TIME=0
until [ $NEXT_WAIT_TIME -eq 15 ] || oc kustomize ${DEPLOY_DIR} | oc apply -f -; do
    sleep $(( NEXT_WAIT_TIME++ ))
done
[ $NEXT_WAIT_TIME -lt 15 ]
