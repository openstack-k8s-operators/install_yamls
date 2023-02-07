#!/bin/bash

oc delete -n default pv ${STORAGE_CLASS}001
oc delete -n default pv ${STORAGE_CLASS}002
oc delete -n default pv ${STORAGE_CLASS}003
oc delete -n default pv ${STORAGE_CLASS}004
oc delete -n default storageclass ${STORAGE_CLASS}
