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

NAMESPACE=$1
SECRET=$2
PASSWORD=$3
if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE as ARG1"; exit 1
fi

if [ -z "$SECRET" ]; then
    echo "Please set SECRET as ARG2"; exit 1
fi

if [ -z "$PASSWORD" ]; then
    echo "Please set PASSWORD as ARG3"; exit 1
fi

if [ ! -d out/${NAMESPACE}/input ]; then
    mkdir -p out/${NAMESPACE}/input
fi

DIR=out/${NAMESPACE}/input

if [ ! -d ${DIR} ]; then
    mkdir -p ${DIR}
fi

pushd ${DIR}

cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
secretGenerator:
- name: ${SECRET}
  literals:
  - AdminPassword=${PASSWORD}
  - CeilometerPassword=${PASSWORD}
  - DbRootPassword=${PASSWORD}
  - DatabasePassword=${PASSWORD}
  - KeystoneDatabasePassword=${PASSWORD}
  - PlacementPassword=${PASSWORD}
  - PlacementDatabasePassword=${PASSWORD}
  - GlancePassword=${PASSWORD}
  - GlanceDatabasePassword=${PASSWORD}
  - NeutronPassword=${PASSWORD}
  - NeutronDatabasePassword=${PASSWORD}
  - CinderPassword=${PASSWORD}
  - CinderDatabasePassword=${PASSWORD}
  - IronicPassword=${PASSWORD}
  - IronicDatabasePassword=${PASSWORD}
  - IronicInspectorPassword=${PASSWORD}
  - IronicInspectorDatabasePassword=${PASSWORD}
  - OctaviaPassword=${PASSWORD}
  - OctaviaDatabasePassword=${PASSWORD}
  - NovaPassword=${PASSWORD}
  - NovaAPIDatabasePassword=${PASSWORD}
  - NovaAPIMessageBusPassword=${PASSWORD}
  - NovaCell0DatabasePassword=${PASSWORD}
  - NovaCell0MessageBusPassword=${PASSWORD}
  - NovaCell1DatabasePassword=${PASSWORD}
  - NovaCell1MessageBusPassword=${PASSWORD}
  - ManilaDatabasePassword=${PASSWORD}
  - ManilaPassword=${PASSWORD}
generatorOptions:
  disableNameSuffixHash: true
  labels:
    type: ${SECRET}
EOF
