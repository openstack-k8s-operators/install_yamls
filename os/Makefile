NAMESPACE ?= openstack
MASTER_PWD ?= 12345678
# Keystone
KEYSTONE_IMG ?= quay.io/openstack-k8s-operators/keystone-operator-index:latest
KEYSTONE_REPO ?= https://github.com/openstack-k8s-operators/keystone-operator.git
KEYSTONE_BRANCH ?= master
KEYSTONE_ADMIN_PWD ?= ${MASTER_PWD}
KEYSTONE_DB_PWD ?= ${MASTER_PWD}
# Mariadb
MARIADB_IMG ?= quay.io/openstack-k8s-operators/mariadb-operator-index:latest
MARIADB_REPO ?= https://github.com/openstack-k8s-operators/mariadb-operator.git
MARIADB_BRANCH ?= master
MARIADB_ROOT_PWD ?= ${MASTER_PWD}

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

OPERATOR_BASE_DIR=out/operator
KEYSTONE_DEPLOY_DIR=out/${NAMESPACE}/keystone/cr
KEYSTONE_OP_DIR=${OPERATOR_BASE_DIR}/keystone-operator
KEYSTONE_API_CR=${KEYSTONE_OP_DIR}/config/samples/keystone_v1beta1_keystoneapi.yaml
MARIADB_INSTANCE_CR=${MARIADB_OP_DIR}/config/samples/mariadb_v1beta1_mariadbdatabase.yaml

.PHONY: keystone_deploy_prep
keystone_deploy_prep: keystone_deploy_cleanup
	mkdir -p ${KEYSTONE_OP_DIR} ${KEYSTONE_DEPLOY_DIR}
	git clone -b ${KEYSTONE_BRANCH} ${KEYSTONE_REPO} ${KEYSTONE_OP_DIR}
	cp ${KEYSTONE_API_CR} ${MARIADB_INSTANCE_CR} ${KEYSTONE_DEPLOY_DIR}
	bash scripts/gen-keystone-kustomize.sh ${NAMESPACE} ${KEYSTONE_ADMIN_PWD} ${KEYSTONE_DB_PWD}

.PHONY: keystone_deploy
keystone_deploy: keystone_deploy_prep
	oc kustomize ${KEYSTONE_DEPLOY_DIR} | oc apply -f -

.PHONY: keystone_deploy_cleanup
keystone_deploy_cleanup:
	oc kustomize ${KEYSTONE_DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${KEYSTONE_OP_DIR} ${KEYSTONE_DEPLOY_DIR}

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

MARIADB_DEPLOY_DIR=out/${NAMESPACE}/mariadb/cr
MARIADB_OP_DIR=${OPERATOR_BASE_DIR}/mariadb-operator
MARIADB_CR=${MARIADB_OP_DIR}/config/samples/mariadb_v1beta1_mariadb.yaml

.PHONY: mariadb_deploy_prep
mariadb_deploy_prep: mariadb_deploy_cleanup
	mkdir -p ${MARIADB_OP_DIR} ${MARIADB_DEPLOY_DIR}
	git clone -b ${MARIADB_BRANCH} ${MARIADB_REPO} ${MARIADB_OP_DIR}
	cp ${MARIADB_CR} ${MARIADB_DEPLOY_DIR}
	bash scripts/gen-mariadb-kustomize.sh ${NAMESPACE} ${MARIADB_ROOT_PWD}
	#bash scripts/gen-mariadb-kustomize.sh mariadb-operator/${MARIADB_CR} ${NAMESPACE} ${MARIADB_ROOT_PWD}

.PHONY: mariadb_deploy
mariadb_deploy: mariadb_deploy_prep
	oc kustomize ${MARIADB_DEPLOY_DIR} | oc apply -f -

.PHONY: mariadb_deploy_cleanup
mariadb_deploy_cleanup:
	oc kustomize ${MARIADB_DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${MARIADB_OP_DIR} ${MARIADB_DEPLOY_DIR}
