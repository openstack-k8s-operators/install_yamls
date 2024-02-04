#!/bin/bash

set -ex


NODE_NAMES=$(oc get node -o name -l node-role.kubernetes.io/worker)
if [ -z "$NODE_NAMES" ]; then
    echo "Unable to determine node name with 'oc' command."
    exit 1
fi

for node in $NODE_NAMES; do
    oc debug $node -T -- chroot /host /usr/bin/bash -c "crictl stats -a -s 10 |  (sed -u 1q; sort -k 2 -h -r)"
done
