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
set -ex
PV_NUM=${PV_NUM:-12}

released=$(oc get pv -o json | jq -r '.items[] | select(.status.phase | test("Released")).metadata.name')

for name in $released; do
    oc patch pv -p '{"spec":{"claimRef": null}}' $name
done
