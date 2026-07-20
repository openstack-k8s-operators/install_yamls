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
OUT=${OUT:-out}

if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

if [ -z "$SECRET" ]; then
    echo "Please set SECRET"; exit 1
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    echo "Please set ADMIN_PASSWORD"; exit 1
fi

if [ -z "$METADATA_SHARED_SECRET" ]; then
    echo "Please set METADATA_SHARED_SECRET"; exit 1
fi

if [ -z "$HEAT_AUTH_ENCRYPTION_KEY" ]; then
    echo "Please set HEAT_AUTH_ENCRYPTION_KEY"; exit 1
fi

if [ -z "$BARBICAN_SIMPLE_CRYPTO_ENCRYPTION_KEY" ]; then
    echo "Please set BARBICAN_SIMPLE_CRYPTO_ENCRYPTION_KEY"; exit 1
fi

if [ -z "$KEYSTONE_FEDERATION_CLIENT_SECRET" ]; then
    echo "Please set KEYSTONE_FEDERATION_CLIENT_SECRET"; exit 1
fi

if [ -z "$KEYSTONE_FEDERATION_CRYPTO_PASSPHRASE" ]; then
    echo "Please set KEYSTONE_FEDERATION_CRYPTO_PASSPHRASE"; exit 1
fi

if [ -z "$LIBVIRT_SECRET" ]; then
    echo "Please set LIBVIRT_SECRET"; exit 1
fi

DIR=${OUT}/${NAMESPACE}/input

if [ ! -d ${DIR} ]; then
    mkdir -p ${DIR}
fi

pushd ${DIR}

set +x
cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
labels:
  - pairs:
      created-by: install_yamls
secretGenerator:
- name: ${SECRET}
  literals:
  - AdminPassword=${ADMIN_PASSWORD}
  - AodhPassword=${AODH_PASSWORD}
  - BarbicanPassword=${BARBICAN_PASSWORD}
  - BarbicanSimpleCryptoKEK=${BARBICAN_SIMPLE_CRYPTO_ENCRYPTION_KEY}
  - CeilometerPassword=${CEILOMETER_PASSWORD}
  - CloudKittyPassword=${CLOUDKITTY_PASSWORD}
  - DbRootPassword=${DB_ROOT_PASSWORD}
  - DatabasePassword=${DATABASE_PASSWORD}
  - DesignatePassword=${DESIGNATE_PASSWORD}
  - PlacementPassword=${PLACEMENT_PASSWORD}
  - GlancePassword=${GLANCE_PASSWORD}
  - NeutronPassword=${NEUTRON_PASSWORD}
  - CinderPassword=${CINDER_PASSWORD}
  - IronicPassword=${IRONIC_PASSWORD}
  - IronicInspectorPassword=${IRONIC_INSPECTOR_PASSWORD}
  - KeystoneOIDCClientSecret=${KEYSTONE_FEDERATION_CLIENT_SECRET}
  - KeystoneOIDCCryptoPassphrase=${KEYSTONE_FEDERATION_CRYPTO_PASSPHRASE}
  - OctaviaPassword=${OCTAVIA_PASSWORD}
  - OctaviaHeartbeatKey=${OCTAVIA_HEARTBEAT_KEY}
  - NovaPassword=${NOVA_PASSWORD}
  - ManilaPassword=${MANILA_PASSWORD}
  - MetadataSecret=${METADATA_SHARED_SECRET}
  - HeatPassword=${HEAT_PASSWORD}
  - HeatAuthEncryptionKey=${HEAT_AUTH_ENCRYPTION_KEY}
  - HeatStackDomainAdminPassword=${HEAT_STACK_DOMAIN_ADMIN_PASSWORD}
  - SwiftPassword=${SWIFT_PASSWORD}
  - WatcherPassword=${WATCHER_PASSWORD}
- name: ${LIBVIRT_SECRET}
  literals:
  - LibvirtPassword=${LIBVIRT_PASSWORD}
- name: octavia-ca-passphrase
  literals:
  - server-ca-passphrase=${OCTAVIA_CA_PASSPHRASE}
generatorOptions:
  disableNameSuffixHash: true
  labels:
    type: ${SECRET}
EOF
set -x
