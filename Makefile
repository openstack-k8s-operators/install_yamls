# general
NAMESPACE           ?= openstack
PASSWORD            ?= 12345678
SECRET              ?= osp-secret
OUT                 ?= ${PWD}/out
# operators gets cloned here
OPERATOR_BASE_DIR   ?= ${OUT}/operator

# default registry and org to pull service images from
SERVICE_REGISTRY    ?= quay.io
SERVICE_ORG         ?= tripleowallabycentos9

# Keystone
KEYSTONE_IMG        ?= quay.io/openstack-k8s-operators/keystone-operator-index:latest
KEYSTONE_REPO       ?= https://github.com/openstack-k8s-operators/keystone-operator.git
KEYSTONE_BRANCH     ?= master
KEYSTONEAPI         ?= config/samples/keystone_v1beta1_keystoneapi.yaml
KEYSTONEAPI_IMG     ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-keystone:current-tripleo

# Mariadb
MARIADB_IMG         ?= quay.io/openstack-k8s-operators/mariadb-operator-index:latest
MARIADB_REPO        ?= https://github.com/openstack-k8s-operators/mariadb-operator.git
MARIADB_BRANCH      ?= master
MARIADB             ?= config/samples/mariadb_v1beta1_mariadb.yaml
MARIADB_DEPL_IMG    ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-mariadb:current-tripleo

# Placement
PLACEMENT_IMG       ?= quay.io/openstack-k8s-operators/placement-operator-index:latest
PLACEMENT_REPO      ?= https://github.com/openstack-k8s-operators/placement-operator.git
PLACEMENT_BRANCH    ?= master
PLACEMENTAPI        ?= config/samples/placement_v1beta1_placementapi.yaml
PLACEMENTAPI_IMG    ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-placement-api:current-tripleo

# Sir Glancealot
GLANCE_IMG          ?= quay.io/openstack-k8s-operators/glance-operator-index:latest
GLANCE_REPO         ?= https://github.com/openstack-k8s-operators/glance-operator.git
GLANCE_BRANCH       ?= master
GLANCEAPI           ?= config/samples/glance_v1beta1_glanceapi.yaml
GLANCEAPI_IMG       ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-glance-api:current-tripleo

# Neutron
NEUTRON_IMG        ?= quay.io/openstack-k8s-operators/neutron-operator-index:latest
NEUTRON_REPO       ?= https://github.com/openstack-k8s-operators/neutron-operator.git
NEUTRON_BRANCH     ?= master
NEUTRONAPI         ?= config/samples/neutron_v1beta1_neutronapi.yaml
NEUTRONAPI_IMG    ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-neutron-server:current-tripleo

# target vars for generic operator install info 1: target name , 2: operator name
define vars
${1}: export NAMESPACE=${NAMESPACE}
${1}: export SECRET=${SECRET}
${1}: export PASSWORD=${PASSWORD}
${1}: export OUT=${OUT}
${1}: export OPERATOR_NAME=${2}
${1}: export OPERATOR_DIR=${OUT}/${NAMESPACE}/${2}/op
${1}: export DEPLOY_DIR=${OUT}/${NAMESPACE}/${2}/cr
endef

.PHONY: all
all: namespace keystone mariadb placement neutron

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: cleanup
cleanup: neutron_cleanup glance_cleanup placement_cleanup keystone_cleanup mariadb_cleanup ## Delete all operators

.PHONY: deploy_cleanup
deploy_cleanup: neutron_deploy_cleanup glance_deploy_cleanup placement_deploy_cleanup keystone_deploy_cleanup mariadb_deploy_cleanup ## Delete all OpenStack service objects

##@ CRC
crc_storage: ## initialize local storage PVs in CRC vm
	bash scripts/create-pv.sh
	bash scripts/gen-crc-pv-kustomize.sh
	oc kustomize ${OUT}/crc | oc apply -f -

crc_storage_cleanup: ## cleanup local storage PVs in CRC vm
	oc get pv | grep local | cut -f 1 -d ' ' | xargs oc delete pv
	oc delete sc local-storage
	#FIXME need to cleanup the actual directories in the CRC VM too

##@ NAMESPACE
.PHONY: namespace
namespace: ## creates the namespace specified via NAMESPACE env var (defaults to openstack)
	$(eval $(call vars,$@))
	bash scripts/gen-namespace.sh
	oc apply -f ${OUT}/${NAMESPACE}/namespace.yaml
	sleep 2
	oc project ${NAMESPACE}

.PHONY: namespace_cleanup
namespace_cleanup: ## deletes the namespace specified via NAMESPACE env var, also runs cleanup for all services to cleanup the namespace prior delete it.
	$(eval $(call vars,$@))
	make keystone_cleanup
	make mariadb_cleanup
	oc delete project ${NAMESPACE}
	rm -Rf ${OUT}/${NAMESPACE}

##@ SERVICE INPUT
.PHONY: input
input: ## creates required secret/CM, used by the services as input
	$(eval $(call vars,$@))
	bash scripts/gen-input-kustomize.sh ${NAMESPACE} ${SECRET} ${PASSWORD}
	oc kustomize ${OUT}/${NAMESPACE}/input | oc apply -f -

.PHONY: input_cleanup
input_cleanup: ## deletes the secret/CM, used by the services as input
	oc kustomize ${OUT}/${NAMESPACE}/input | oc delete --ignore-not-found=true -f -
	rm -Rf ${OUT}/${NAMESPACE}/input

##@ KEYSTONE
.PHONY: keystone_prep
keystone_prep: export IMAGE=${KEYSTONE_IMG}
keystone_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,keystone))
	bash scripts/gen-olm.sh

.PHONY: keystone
keystone: namespace keystone_prep ## installs the operator, also runs the prep step. Set KEYSTONE_IMG for custom image.
	$(eval $(call vars,$@,keystone))
	oc apply -f ${OPERATOR_DIR}

.PHONY: keystone_cleanup
keystone_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,keystone))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: keystone_deploy_prep
keystone_deploy_prep: export KIND=KeystoneAPI
keystone_deploy_prep: export IMAGE=${KEYSTONEAPI_IMG}
keystone_deploy_prep: keystone_deploy_cleanup ## prepares the CR to install the service based on the service sample file KEYSTONEAPI
	$(eval $(call vars,$@,keystone))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${KEYSTONE_BRANCH} ${KEYSTONE_REPO} && popd
	cp ${OPERATOR_BASE_DIR}/keystone-operator/${KEYSTONEAPI} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: keystone_deploy
keystone_deploy: input keystone_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set KEYSTONE_REPO and KEYSTONE_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,keystone))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: keystone_deploy_cleanup
keystone_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,keystone))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/keystone-operator ${DEPLOY_DIR}

##@ MARIADB
mariadb_prep: export IMAGE=${MARIADB_IMG}
mariadb_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,mariadb))
	bash scripts/gen-olm.sh

.PHONY: mariadb
mariadb: namespace mariadb_prep ## installs the operator, also runs the prep step. Set MARIADB_IMG for custom image.
	$(eval $(call vars,$@,mariadb))
	oc apply -f ${OPERATOR_DIR}

.PHONY: mariadb_cleanup
mariadb_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,mariadb))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: mariadb_deploy_prep
mariadb_deploy_prep: export KIND=MariaDB
mariadb_deploy_prep: export IMAGE="${MARIADB_DEPL_IMG}"
mariadb_deploy_prep: mariadb_deploy_cleanup ## prepares the CRs files to install the service based on the service sample file MARIADB
	$(eval $(call vars,$@,mariadb))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${MARIADB_BRANCH} ${MARIADB_REPO} && popd
	cp ${OPERATOR_BASE_DIR}/mariadb-operator/${MARIADB} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: mariadb_deploy
mariadb_deploy: input mariadb_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set MARIADB_REPO and MARIADB_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,mariadb))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: mariadb_deploy_cleanup
mariadb_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,mariadb))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/mariadb-operator ${DEPLOY_DIR}

##@ PLACEMENT
.PHONY: placement_prep
placement_prep: export IMAGE=${PLACEMENT_IMG}
placement_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,placement))
	bash scripts/gen-olm.sh

.PHONY: placement
placement: namespace placement_prep ## installs the operator, also runs the prep step. Set PLACEMENT_IMG for custom image.
	$(eval $(call vars,$@,placement))
	oc apply -f ${OPERATOR_DIR}

.PHONY: placement_cleanup
placement_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,placement))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: placement_deploy_prep
placement_deploy_prep: export KIND=PlacementAPI
placement_deploy_prep: export IMAGE=${PLACEMENTAPI_IMG}
placement_deploy_prep: placement_deploy_cleanup ## prepares the CR to install the service based on the service sample file PLACEMENTAPI
	$(eval $(call vars,$@,placement))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${PLACEMENT_BRANCH} ${PLACEMENT_REPO} && popd
	cp ${OPERATOR_BASE_DIR}/placement-operator/${PLACEMENTAPI} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: placement_deploy
placement_deploy: input placement_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set PLACEMENT_REPO and PLACEMENT_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,placement))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: placement_deploy_cleanup
placement_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,placement))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/placement-operator ${DEPLOY_DIR}

##@ GLANCE
.PHONY: glance_prep
glance_prep: export IMAGE=${GLANCE_IMG}
glance_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,glance))
	bash scripts/gen-olm.sh

.PHONY: glance
glance: namespace glance_prep ## installs the operator, also runs the prep step. Set GLANCE_IMG for custom image.
	$(eval $(call vars,$@,glance))
	oc apply -f ${OPERATOR_DIR}

.PHONY: glance_cleanup
glance_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,glance))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: glance_deploy_prep
glance_deploy_prep: export KIND=GlanceAPI
glance_deploy_prep: export IMAGE=${GLANCEAPI_IMG}
glance_deploy_prep: glance_deploy_cleanup ## prepares the CR to install the service based on the service sample file GLANCEAPI
	$(eval $(call vars,$@,glance))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${GLANCE_BRANCH} ${GLANCE_REPO} && popd
	cp ${OPERATOR_BASE_DIR}/glance-operator/${GLANCEAPI} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: glance_deploy
glance_deploy: input glance_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set GLANCE_REPO and GLANCE_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,glance))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: glance_deploy_cleanup
glance_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,glance))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/glance-operator ${DEPLOY_DIR}

##@ NEUTRON
.PHONY: neutron_prep
neutron_prep: export IMAGE=${NEUTRON_IMG}
neutron_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,neutron))
	bash scripts/gen-olm.sh

.PHONY: neutron
neutron: namespace neutron_prep ## installs the operator, also runs the prep step. Set NEUTRON_IMG for custom image.
	$(eval $(call vars,$@,neutron))
	oc apply -f ${OPERATOR_DIR}

.PHONY: neutron_cleanup
neutron_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,neutron))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: neutron_deploy_prep
neutron_deploy_prep: export KIND=NeutronAPI
neutron_deploy_prep: export IMAGE=${NEUTRONAPI_IMG}
neutron_deploy_prep: neutron_deploy_cleanup ## prepares the CR to install the service based on the service sample file NEUTRONAPI
	$(eval $(call vars,$@,neutron))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${NEUTRON_BRANCH} ${NEUTRON_REPO} && popd
	cp ${OPERATOR_BASE_DIR}/neutron-operator/${NEUTRONAPI} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: neutron_deploy
neutron_deploy: input neutron_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set NEUTRON_REPO and NEUTRON_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,neutron))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: neutron_deploy_cleanup
neutron_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,neutron))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/neutron-operator ${DEPLOY_DIR}
