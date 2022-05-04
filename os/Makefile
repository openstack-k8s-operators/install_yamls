NAMESPACE ?= openstack
KEYSTONE_IMG ?= quay.io/openstack-k8s-operators/keystone-operator-index:latest
MARIADB_IMG ?= quay.io/openstack-k8s-operators/mariadb-operator-index:latest

all: namespace keystone mariadb

# CRC
crc_storage:
	bash scripts/create-pv.sh
	bash scripts/gen-crc-pv-kustomize.sh
	oc kustomize out/crc | oc apply -f -

crc_storage_cleanup:
	oc get pv | grep local | cut -f 1 -d ' ' | xargs oc delete pv
	oc delete sc local-storage
	#FIXME need to cleanup the actual directories in the CRC VM too

# NAMESPACE
.PHONY: namespace
namespace:
	bash scripts/gen-namespace.sh ${NAMESPACE}
	oc apply -f out/${NAMESPACE}/namespace.yaml
	sleep 2
	oc project ${NAMESPACE}

.PHONY: namespace_cleanup
namespace_cleanup:
	make keystone_cleanup
	make mariadb_cleanup
	oc delete project ${NAMESPACE}
	rm -Rf out/${NAMESPACE}

# KEYSTONE
keystone_prep:
	bash scripts/gen-olm.sh ${NAMESPACE} keystone ${KEYSTONE_IMG}

.PHONY: keystone
keystone: namespace keystone_prep
	oc apply -f out/${NAMESPACE}/keystone

.PHONY: keystone_cleanup
keystone_cleanup: 
	oc delete -n ${NAMESPACE} csv keystone-operator.v0.0.1 || true
	oc delete -n ${NAMESPACE} subscription keystone-operator || true
	oc delete -n ${NAMESPACE} catalogsource keystone-operator-index || true
	rm -Rf out/${NAMESPACE}/keystone

# MARIADB
mariadb_prep:
	bash scripts/gen-olm.sh ${NAMESPACE} mariadb ${MARIADB_IMG}

.PHONY: mariadb
mariadb: namespace mariadb_prep
	oc apply -f out/${NAMESPACE}/mariadb

.PHONY: mariadb_cleanup
mariadb_cleanup: 
	oc delete -n ${NAMESPACE} csv mariadb-operator.v0.0.1 || true
	oc delete -n ${NAMESPACE} subscription mariadb-operator || true
	oc delete -n ${NAMESPACE} catalogsource mariadb-operator-index || true
	rm -Rf out/${NAMESPACE}/mariadb
