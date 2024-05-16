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

OPERATORS="cert-manager"

for operator in $OPERATORS; do
    n=0
    retries="${1:-20}"  # Number of retries with a default value of 20
    while true; do
        oc get packagemanifests | grep $operator
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
