#!/bin/bash

NAMESPACE=$1
if [ -z "$NAMESPACE" ]; then
  echo "Please set NAMESPACE as ARG1"; exit 1
fi

if [ ! -d out/${NAMESPACE} ]; then
  mkdir -p out/${NAMESPACE}
fi

# can share this for all the operators, won't get re-applied if it already exists
cat > out/$NAMESPACE/namespace.yaml <<EOF_CAT
apiVersion: v1
kind: Namespace
metadata:
    name: ${NAMESPACE}
EOF_CAT
