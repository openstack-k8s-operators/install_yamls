#!/bin/bash
NODE_NAME=$(oc get node -o name)
if [ -z "$NODE_NAME" ]; then
  echo "Unable to determine node name with 'oc' command."
  exit 1
fi
oc debug $NODE_NAME -T -- chroot /host /usr/bin/bash -c "for i in {0..5}; do echo \"creating dir /mnt/openstack/pv00\$i\"; mkdir -p /mnt/openstack/pv00\$i; done"
