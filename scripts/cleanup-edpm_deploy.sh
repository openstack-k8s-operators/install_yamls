#!/bin/bash
set -ex

# Remove all the networking agent entries in case we do another EDPM deploy
AGENTS=$(oc rsh openstackclient bash -c 'openstack network agent list | grep -E "edpm-compute-.+\.ctlplane" | cut -d" " -f2 | xargs echo -n')
if [[ -n "${AGENTS}" ]]; then
    oc rsh openstackclient bash -c "openstack network agent delete ${AGENTS}"
fi
