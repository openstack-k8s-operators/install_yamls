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

# expect that the common.sh is in the same dir as the calling script
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
. ${SCRIPTPATH}/common.sh --source-only

if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

if [ -z "$KIND" ]; then
    echo "Please set SERVICE"; exit 1
fi

if [ -z "$SECRET" ]; then
    echo "Please set SECRET"; exit 1
fi

if [ -z "$DEPLOY_DIR" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ -z "$IMAGE" ]; then
    echo "Please set IMAGE"; exit 1
fi

NAME=${KIND,,}

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

pushd ${DEPLOY_DIR}

cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
namespace: ${NAMESPACE}
patches:
- target:
    kind: ${KIND}
  patch: |-
    - op: replace
      path: /spec/secret
      value: ${SECRET}
    - op: replace
      path: /spec/storageClass
      value: ${STORAGE_CLASS}
EOF

if [ "$UPDATE_CONTAINERS" == "true" ]; then
cat <<EOF >update_containers_patch.yaml
apiVersion: core.openstack.org/v1beta1
kind: OpenStackControlPlane
metadata:
  name: openstack
spec:
  keystone:
    template:
      containerImage: ${KEYSTONEAPI_IMG}
  mariadb:
    template:
      containerImage: ${MARIADB_DEPL_IMG}
  placement:
    template:
      containerImage: ${PLACEMENTAPI_IMG}
  glance:
    template:
      containerImage: ${GLANCEAPI_IMG}
      glanceAPIInternal:
        containerImage: ${GLANCEAPI_IMG}
      glanceAPIExternal:
        containerImage: ${GLANCEAPI_IMG}
  cinder:
    template:
      cinderAPI:
        containerImage: ${CINDERAPI_IMG}
      cinderScheduler:
        containerImage: ${CINDERSCHEDULER_IMG}
      cinderBackup:
        containerImage: ${CINDERBACKUP_IMG}
      cinderVolumes:
        volume1:
          containerImage: ${CINDERVOLUME_IMG}
  ovn:
    template:
      ovnDBCluster:
        ovndbcluster-nb:
          containerImage: ${OVNBDS_IMG}
        ovndbcluster-sb:
          containerImage: ${OVSBDS_IMG}
      ovnNorthd:
        containerImage: ${OVNNORTHD_IMG}
  ovs:
    template:
      ovsContainerImage: ${OVSSERVICE_IMG}
      ovnContainerImage: ${OVNCONTROLLER_IMG}
  neutron:
    template:
      containerImage: ${NEUTRONSERVER_IMG}
EOF

cat <<EOF >>kustomization.yaml
patchesStrategicMerge:
  - update_containers_patch.yaml
EOF

fi
if [ "$IMAGE" != "unused" ]; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/containerImage
      value: ${IMAGE}
EOF
fi

kustomization_add_resources

popd
