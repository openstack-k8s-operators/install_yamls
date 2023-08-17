#!/bin/bash
set -ex

# First, remove all PVCs still bound. Some operators (eg mariadb-operator) do
# not remove pvc after removing deployments
for pvc in `oc get pv --selector provisioned-by=crc-devsetup --no-headers | grep Bound | awk '{print $6}'`; do
    NS=`echo $pvc | cut -d '/' -f 1`
    NAME=`echo $pvc | cut -d '/' -f 2`
    oc delete -n ${NS} pvc/${NAME} --ignore-not-found
done

# Then remove all PVs
for pv in `oc get pv --selector provisioned-by=crc-devsetup --no-headers | awk '{print $1}'`; do
    oc delete pv/${pv}
done
