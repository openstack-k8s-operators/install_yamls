#!/bin/bash
set -x

if [ -z "${OPERATOR_NAMESPACE}" ]; then
    echo "Please set OPERATOR_NAMESPACE"; exit 1
fi

if [ -z "$OPERATOR_NAME" ]; then
    echo "Please set OPERATOR_NAME"; exit 1
fi

if [ "$OPERATOR_NAME" = "rabbitmq-cluster" ]; then
    DEPL_NAME="rabbitmq-cluster-operator"
else
    DEPL_NAME=${OPERATOR_NAME}-operator-controller-manager
fi

REPLICAS=$(oc get -n "${OPERATOR_NAMESPACE}" deployment ${DEPL_NAME} -o json | jq -e '.status.availableReplicas')
if [ "$REPLICAS" != "1" ]; then
    exit 1
fi
echo "Succeeded"
exit 0
