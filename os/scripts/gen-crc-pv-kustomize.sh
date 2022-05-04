#!/bin/bash

if [ ! -d out/crc ]; then
  mkdir -p out/crc
fi

NODE_NAME=$(oc get node -o name | sed -e 's|node/||')
if [ -z "$NODE_NAME" ]; then
  echo "Unable to determine node name with 'oc' command."
  exit 1
fi

cat > out/crc/kustomization.yaml <<EOF_CAT
resources:
- ../../crc
patches:
- patch: |-
    - op: replace
      path: /spec/nodeAffinity/required/nodeSelectorTerms/0/matchExpressions/0/values/0
      value: $NODE_NAME
  target:
    kind: PersistentVolume
EOF_CAT
