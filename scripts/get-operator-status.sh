#!/bin/bash
set -x

if [ -z "${OPERATOR_NAMESPACE}" ]; then
    echo "Please set OPERATOR_NAMESPACE"; exit 1
fi

if [ -z "$OPERATOR_NAME" ]; then
    echo "Please set OPERATOR_NAME"; exit 1
fi

CSVNAME=$(oc get csv -n ${OPERATOR_NAMESPACE} -o jsonpath='{range .items[*]}{@.metadata.name}{"\n"}{end}' | egrep -e "^${OPERATOR_NAME}-operator\.v")
if [ -z "$CSVNAME" ]; then
    echo "NOTFOUND"
    exit 1
fi

PHASE=$(oc get -n ${OPERATOR_NAMESPACE} csv/${CSVNAME} -o jsonpath='{.status.phase}')
echo $PHASE
if [ "$PHASE" != "Succeeded" ]; then
    exit 1
fi
exit 0
