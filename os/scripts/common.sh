#!/bin//bash
#
# Copyright 2018 Red Hat Inc.
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

set -e

#
# add_resources add all yaml files, excepy kustomization of the
# directory to the resources section of the kustomization.yaml file
#
function kustomization_add_resources {
  echo merge config dir $1

  # it is not possible to use wild cards in resources field
  # https://github.com/kubernetes-sigs/kustomize/issues/119
  yamls=$(find . -type f -name "*.yaml" | grep -v kustomization)
  for y in ${yamls[@]}; do
    kustomize edit add resource $y
  done
}

