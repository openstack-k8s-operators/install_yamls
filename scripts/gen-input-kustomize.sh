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

if [ -z "$PASSWORD" ]; then
    echo "Please set PASSWORD"; exit 1
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
  - AdminPassword=${PASSWORD}
  - AodhPassword=${PASSWORD}
  - BarbicanPassword=${PASSWORD}
  - BarbicanSimpleCryptoKEK=${BARBICAN_SIMPLE_CRYPTO_ENCRYPTION_KEY}
  - CeilometerPassword=${PASSWORD}
  - CloudKittyPassword=${PASSWORD}
  - DbRootPassword=${PASSWORD}
  - DatabasePassword=${PASSWORD}
  - DesignatePassword=${PASSWORD}
  - PlacementPassword=${PASSWORD}
  - GlancePassword=${PASSWORD}
  - NeutronPassword=${PASSWORD}
  - CinderPassword=${PASSWORD}
  - IronicPassword=${PASSWORD}
  - IronicInspectorPassword=${PASSWORD}
  - KeystoneOIDCClientSecret=${KEYSTONE_FEDERATION_CLIENT_SECRET}
  - KeystoneOIDCCryptoPassphrase=${KEYSTONE_FEDERATION_CRYPTO_PASSPHRASE}
  - OctaviaPassword=${PASSWORD}
  - OctaviaHeartbeatKey=${PASSWORD}
  - NovaPassword=${PASSWORD}
  - ManilaPassword=${PASSWORD}
  - MetadataSecret=${METADATA_SHARED_SECRET}
  - HeatPassword=${PASSWORD}
  - HeatAuthEncryptionKey=${HEAT_AUTH_ENCRYPTION_KEY}
  - HeatStackDomainAdminPassword=${PASSWORD}
  - SwiftPassword=${PASSWORD}
  - WatcherPassword=${PASSWORD}
- name: ${LIBVIRT_SECRET}
  literals:
  - LibvirtPassword=${PASSWORD}
- name: octavia-ca-passphrase
  literals:
  - server-ca-passphrase=${PASSWORD}
generatorOptions:
  disableNameSuffixHash: true
  labels:
    type: ${SECRET}
EOF
