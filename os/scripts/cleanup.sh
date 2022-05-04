#!/bin/bash

oc delete -n default pv local-storage001
oc delete -n default pv local-storage002
oc delete -n default pv local-storage003
oc delete -n default pv local-storage004
oc delete -n default storageclass local-storage
