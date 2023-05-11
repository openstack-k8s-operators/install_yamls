#!/bin/bash

oc project openstack
if [ $? != 0 ]; then
    oc project default
fi
