#!/bin/bash
set -x

if [ -z "${OPERATOR_NAMESPACE}" ]; then
    echo "Please set OPERATOR_NAMESPACE"; exit 1
fi

if [ -z "$OPERATOR_NAME" ]; then
    echo "Please set OPERATOR_NAME"; exit 1
fi

REPLICAS=$(oc get -n "${OPERATOR_NAMESPACE}" deployment ${OPERATOR_NAME}-operator-controller-manager -o json | jq -e '.status.availableReplicas')
if [ "$REPLICAS" != "1" ]; then
    exit 1
fi
echo "Succeeded"
exit 0
