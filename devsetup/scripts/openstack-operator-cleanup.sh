#!/bin/bash

echo Openstack operator and crc cleanup
echo ==================================

cd ..
make openstack_cleanup && \
make ceph_cleanup && \
make crc_storage_cleanup && \
echo Environment teardown completed successfuly || \
echo Environment teardown failed !
echo ==========================================
