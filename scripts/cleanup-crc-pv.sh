#!/bin/bash
set -ex

LABEL_SELECTOR="provisioned-by=crc-devsetup"
if [ -n "${STORAGE_ID}" ]; then
    LABEL_SELECTOR="${LABEL_SELECTOR},crc-devsetup-storage-id=${STORAGE_ID}"
fi

# First, remove all PVCs still bound. Some operators (eg mariadb-operator) do
# not remove pvc after removing deployments
for pvc in $(oc get pv --selector "${LABEL_SELECTOR}" --no-headers | grep Bound | awk '{print $6}'); do
    NS=$(echo $pvc | cut -d '/' -f 1)
    NAME=$(echo $pvc | cut -d '/' -f 2)
    oc delete -n ${NS} pvc/${NAME} --ignore-not-found
done

# Then remove all PVs
for pv in $(oc get pv --selector "${LABEL_SELECTOR}" --no-headers | awk '{print $1}'); do
    oc delete pv/${pv}
done
