# general
SHELL := /bin/bash
NAMESPACE           ?= openstack
PASSWORD            ?= 12345678
SECRET              ?= osp-secret
OUT                 ?= ${PWD}/out
INSTALL_YAMLS       ?= ${PWD}  # used for kuttl tests

# operators gets cloned here
OPERATOR_BASE_DIR   ?= ${OUT}/operator

# default registry and org to pull service images from
SERVICE_REGISTRY    ?= quay.io
SERVICE_ORG         ?= tripleozedcentos9

# storage (used by some operators)
STORAGE_CLASS       ?= "local-storage"

# OpenStack Operator
OPENSTACK_IMG        ?= quay.io/openstack-k8s-operators/openstack-operator-index:latest
OPENSTACK_REPO       ?= https://github.com/openstack-k8s-operators/openstack-operator.git
OPENSTACK_BRANCH     ?= master
OPENSTACK_CTLPLANE   ?= config/samples/core_v1beta1_openstackcontrolplane.yaml
OPENSTACK_CR         ?= ${OPERATOR_BASE_DIR}/openstack-operator/${OPENSTACK_CTLPLANE}

# Infra Operator
INFRA_IMG        ?= quay.io/openstack-k8s-operators/infra-operator-index:latest
INFRA_REPO       ?= https://github.com/openstack-k8s-operators/infra-operator.git
INFRA_BRANCH     ?= master

# Keystone
KEYSTONE_IMG        ?= quay.io/openstack-k8s-operators/keystone-operator-index:latest
KEYSTONE_REPO       ?= https://github.com/openstack-k8s-operators/keystone-operator.git
KEYSTONE_BRANCH     ?= master
KEYSTONEAPI         ?= config/samples/keystone_v1beta1_keystoneapi.yaml
KEYSTONEAPI_CR      ?= ${OPERATOR_BASE_DIR}/keystone-operator/${KEYSTONEAPI}
KEYSTONEAPI_IMG     ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-keystone:current-tripleo
KEYSTONE_KUTTL_CONF ?= ${OPERATOR_BASE_DIR}/keystone-operator/kuttl-test.yaml
KEYSTONE_KUTTL_DIR  ?= ${OPERATOR_BASE_DIR}/keystone-operator/tests/kuttl/tests

# Mariadb
MARIADB_IMG         ?= quay.io/openstack-k8s-operators/mariadb-operator-index:latest
MARIADB_REPO        ?= https://github.com/openstack-k8s-operators/mariadb-operator.git
MARIADB_BRANCH      ?= master
MARIADB             ?= config/samples/mariadb_v1beta1_mariadb.yaml
MARIADB_CR          ?= ${OPERATOR_BASE_DIR}/mariadb-operator/${MARIADB}
MARIADB_DEPL_IMG    ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-mariadb:current-tripleo
MARIADB_KUTTL_CONF ?= ${OPERATOR_BASE_DIR}/mariadb-operator/kuttl-test.yaml
MARIADB_KUTTL_DIR  ?= ${OPERATOR_BASE_DIR}/mariadb-operator/tests/kuttl/tests

# Placement
PLACEMENT_IMG       ?= quay.io/openstack-k8s-operators/placement-operator-index:latest
PLACEMENT_REPO      ?= https://github.com/openstack-k8s-operators/placement-operator.git
PLACEMENT_BRANCH    ?= master
PLACEMENTAPI        ?= config/samples/placement_v1beta1_placementapi.yaml
PLACEMENTAPI_CR     ?= ${OPERATOR_BASE_DIR}/placement-operator/${PLACEMENTAPI}
PLACEMENTAPI_IMG    ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-placement-api:current-tripleo

# Sir Glancealot
GLANCE_IMG          ?= quay.io/openstack-k8s-operators/glance-operator-index:latest
GLANCE_REPO         ?= https://github.com/openstack-k8s-operators/glance-operator.git
GLANCE_BRANCH       ?= master
GLANCE              ?= config/samples/glance_v1beta1_glance.yaml
GLANCE_CR           ?= ${OPERATOR_BASE_DIR}/glance-operator/${GLANCE}
GLANCEAPI_IMG       ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-glance-api:current-tripleo

# Ovn
OVN_IMG             ?= quay.io/openstack-k8s-operators/ovn-operator-index:latest
OVN_REPO            ?= https://github.com/openstack-k8s-operators/ovn-operator.git
OVN_BRANCH          ?= main
OVNDBS              ?= config/samples/ovn_v1beta1_ovndbcluster.yaml
OVNDBS_CR           ?= ${OPERATOR_BASE_DIR}/ovn-operator/${OVNDBS}
OVNNORTHD           ?= config/samples/ovn_v1beta1_ovnnorthd.yaml
OVNNORTHD_CR        ?= ${OPERATOR_BASE_DIR}/ovn-operator/${OVNNORTHD}
OVN_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/ovn-operator/kuttl-test.yaml
OVN_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/ovn-operator/tests/kuttl/tests

# Ovs
OVS_IMG             ?= quay.io/openstack-k8s-operators/ovs-operator-index:latest
OVS_REPO            ?= https://github.com/openstack-k8s-operators/ovs-operator.git
OVS_BRANCH          ?= main
OVS                 ?= config/samples/ovs_v1beta1_ovs.yaml
OVS_CR              ?= ${OPERATOR_BASE_DIR}/ovs-operator/${OVS}

# Neutron
NEUTRON_IMG        ?= quay.io/openstack-k8s-operators/neutron-operator-index:latest
NEUTRON_REPO       ?= https://github.com/openstack-k8s-operators/neutron-operator.git
NEUTRON_BRANCH     ?= master
NEUTRONAPI         ?= config/samples/neutron_v1beta1_neutronapi.yaml
NEUTRONAPI_CR      ?= ${OPERATOR_BASE_DIR}/neutron-operator/${NEUTRONAPI}
NEUTRONAPI_IMG     ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-neutron-server:current-tripleo

# Cinder
CINDER_IMG       ?= quay.io/openstack-k8s-operators/cinder-operator-index:latest
CINDER_REPO      ?= https://github.com/openstack-k8s-operators/cinder-operator.git
CINDER_BRANCH    ?= master
CINDER           ?= config/samples/cinder_v1beta1_cinder.yaml
CINDER_CR        ?= ${OPERATOR_BASE_DIR}/cinder-operator/${CINDER}
# TODO: Image customizations for all Cinder services

# Rabbitmq
RABBITMQ_IMG         ?= quay.io/openstack-k8s-operators/rabbitmq-cluster-operator-index:latest
RABBITMQ_REPO      ?= https://github.com/openstack-k8s-operators/rabbitmq-cluster-operator.git
RABBITMQ_BRANCH    ?= patches
RABBITMQ           ?= docs/examples/default-security-context/rabbitmq.yaml
RABBITMQ_CR        ?= ${OPERATOR_BASE_DIR}/rabbitmq-operator/${RABBITMQ}

# Ironic
IRONIC_IMG       ?= quay.io/openstack-k8s-operators/ironic-operator-index:latest
IRONIC_REPO      ?= https://github.com/openstack-k8s-operators/ironic-operator.git
IRONIC_BRANCH    ?= master
IRONIC           ?= config/samples/ironic_v1beta1_ironic.yaml
IRONIC_CR        ?= ${OPERATOR_BASE_DIR}/ironic-operator/${IRONIC}
IRONIC_KUTTL_CONF ?= ${OPERATOR_BASE_DIR}/ironic-operator/kuttl-test.yaml
IRONIC_KUTTL_DIR  ?= ${OPERATOR_BASE_DIR}/ironic-operator/tests/kuttl/tests

# Octavia
OCTAVIA_IMG       ?= quay.io/openstack-k8s-operators/octavia-operator-index:latest
OCTAVIA_REPO      ?= https://github.com/openstack-k8s-operators/octavia-operator.git
OCTAVIA_BRANCH    ?= main
OCTAVIAAPI        ?= config/samples/octavia_v1beta1_octaviaapi.yaml
OCTAVIAAPI_CR     ?= ${OPERATOR_BASE_DIR}/octavia-operator/${OCTAVIAAPI}
OCTAVIAAPI_IMG    ?= ${SERVICE_REGISTRY}/${SERVICE_ORG}/openstack-octavia-api:current-tripleo
OCTAVIA_KUTTL_CONF ?= ${OPERATOR_BASE_DIR}/octavia-operator/kuttl-test.yaml
OCTAVIA_KUTTL_DIR  ?= ${OPERATOR_BASE_DIR}/octavia-operator/tests/kuttl/tests

# Nova
NOVA_IMG       ?= quay.io/openstack-k8s-operators/nova-operator-index:latest
NOVA_REPO      ?= https://github.com/openstack-k8s-operators/nova-operator.git
NOVA_BRANCH    ?= master
# NOTE(gibi): We intentionally not using the default nova sample here
# as that would require two RabbitMQCluster to be deployed which a) is not what
# the make rabbitmq_deploy target does ii) required extra resource in the dev
# environment.
NOVA           ?= config/samples/nova_v1beta1_nova_collapsed_cell.yaml
NOVA_CR        ?= ${OPERATOR_BASE_DIR}/nova-operator/${NOVA}

# AnsibleEE
ANSIBLEEE_IMG       ?= quay.io/openstack-k8s-operators/openstack-ansibleee-operator-index:latest
ANSIBLEEE_REPO      ?= https://github.com/openstack-k8s-operators/openstack-ansibleee-operator
ANSIBLEEE_BRANCH    ?= main
ANSIBLEEE           ?= config/samples/_v1alpha1_ansibleee.yaml
ANSIBLEEE_CR        ?= ${OPERATOR_BASE_DIR}/ansibleee-operator/${ANSIBLEEE}

# Ceph
CEPH_IMG       ?= quay.io/ceph/daemon:latest-quincy

# target vars for generic operator install info 1: target name , 2: operator name
define vars
${1}: export NAMESPACE=${NAMESPACE}
${1}: export SECRET=${SECRET}
${1}: export PASSWORD=${PASSWORD}
${1}: export STORAGE_CLASS=${STORAGE_CLASS}
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
cleanup: nova_cleanup octavia_cleanup neutron_cleanup ovn_cleanup ironic_cleanup cinder_cleanup glance_cleanup placement_cleanup keystone_cleanup mariadb_cleanup ## Delete all operators

.PHONY: deploy_cleanup
deploy_cleanup: nova_deploy_cleanup octavia_deploy_cleanup neutron_deploy_cleanup ovn_deploy_cleanup ironic_deploy_cleanup cinder_deploy_cleanup glance_deploy_cleanup placement_deploy_cleanup keystone_deploy_cleanup mariadb_deploy_cleanup ## Delete all OpenStack service objects

##@ CRC
.PHONY: crc_storage
crc_storage: ## initialize local storage PVs in CRC vm
	$(eval $(call vars,$@))
	bash scripts/create-pv.sh
	bash scripts/gen-crc-pv-kustomize.sh
	oc apply -f ${OUT}/crc/storage.yaml

.PHONY: crc_storage_cleanup
crc_storage_cleanup: ## cleanup local storage PVs in CRC vm
	$(eval $(call vars,$@))
	oc get pv | grep ${STORAGE_CLASS} | cut -f 1 -d ' ' | xargs oc delete pv
	oc delete sc ${STORAGE_CLASS}
	bash scripts/delete-pv.sh

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
	oc get secret/${SECRET} || oc kustomize ${OUT}/${NAMESPACE}/input | oc apply -f -

.PHONY: input_cleanup
input_cleanup: ## deletes the secret/CM, used by the services as input
	oc kustomize ${OUT}/${NAMESPACE}/input | oc delete --ignore-not-found=true -f -
	rm -Rf ${OUT}/${NAMESPACE}/input

##@ OPENSTACK
.PHONY: openstack_prep
openstack_prep: export IMAGE=${OPENSTACK_IMG}
openstack_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,openstack))
	bash scripts/gen-olm.sh

.PHONY: openstack
openstack: namespace openstack_prep ## installs the operator, also runs the prep step. Set OPENSTACK_IMG for custom image.
	$(eval $(call vars,$@,openstack))
	oc apply -f ${OPERATOR_DIR}

.PHONY: openstack_cleanup
openstack_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,openstack))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: openstack_deploy_prep
openstack_deploy_prep: export KIND=OpenStackControlPlane
openstack_deploy_prep: export IMAGE=unused
openstack_deploy_prep: openstack_deploy_cleanup ## prepares the CR to install the service based on the service sample file OPENSTACK
	$(eval $(call vars,$@,openstack))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${OPENSTACK_BRANCH} ${OPENSTACK_REPO} && popd
	cp ${OPENSTACK_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: openstack_deploy
openstack_deploy: input openstack_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set OPENSTACK_REPO and OPENSTACK_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,openstack))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: openstack_deploy_cleanup
openstack_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,openstack))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/openstack-operator ${DEPLOY_DIR}

.PHONY: openstack_crds
openstack_crds: ## installs all openstack CRDs. Useful for infrastructure dev
	mkdir -p ${OUT}/openstack_crds
	podman pull quay.io/openstack-k8s-operators/openstack-operator-bundle:latest
	podman image save -o ${OUT}/openstack_crds --compress --format docker-dir quay.io/openstack-k8s-operators/openstack-operator-bundle:latest
	tar xvf $$(file ${OUT}/openstack_crds/* | grep gzip | cut -f 1 -d ':') -C ${OUT}/openstack_crds
	for X in $$(grep -l CustomResourceDefinition out/openstack_crds/manifests/*); do oc apply -f $$X; done

##@ INFRA
.PHONY: infra_prep
infra_prep: export IMAGE=${INFRA_IMG}
infra_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,infra))
	bash scripts/gen-olm.sh

.PHONY: infra
infra: namespace infra_prep ## installs the operator, also runs the prep step. Set INFRA_IMG for custom image.
	$(eval $(call vars,$@,infra))
	oc apply -f ${OPERATOR_DIR}

.PHONY: infra_cleanup
infra_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,infra))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

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
	cp ${KEYSTONEAPI_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: keystone_deploy
keystone_deploy: input keystone_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set KEYSTONE_REPO and KEYSTONE_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,keystone))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: keystone_deploy_validate
keystone_deploy_validate: input namespace ## checks that keystone was properly deployed. Set KEYSTONE_KUTTL_DIR to use assert file from custom repo.
	kubectl-kuttl assert -n ${NAMESPACE} ${KEYSTONE_KUTTL_DIR}/../common/assert_sample_deployment.yaml --timeout 180

.PHONY: keystone_deploy_cleanup
keystone_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,keystone))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/keystone-operator ${DEPLOY_DIR}
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database keystone;" || true

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
	cp ${MARIADB_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: mariadb_deploy
mariadb_deploy: input mariadb_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set MARIADB_REPO and MARIADB_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,mariadb))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: mariadb_deploy_validate
mariadb_deploy_validate: input namespace ## checks that mariadb was properly deployed. Set KEYSTONE_KUTTL_DIR to use assert file from custom repo.
	kubectl-kuttl assert -n ${NAMESPACE} ${MARIADB_KUTTL_DIR}/../common/assert_sample_deployment.yaml --timeout 180

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
	cp ${PLACEMENTAPI_CR} ${DEPLOY_DIR}
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
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database placement;" || true

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
glance_deploy_prep: export KIND=Glance
glance_deploy_prep: export IMAGE=${GLANCEAPI_IMG}
glance_deploy_prep: glance_deploy_cleanup ## prepares the CR to install the service based on the service sample file GLANCE
	$(eval $(call vars,$@,glance))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${GLANCE_BRANCH} ${GLANCE_REPO} && popd
	cp ${GLANCE_CR} ${DEPLOY_DIR}
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
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database glance;" || true

##@ OVN
.PHONY: ovn_prep
ovn_prep: export IMAGE=${OVN_IMG}
ovn_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,ovn))
	bash scripts/gen-olm.sh

.PHONY: ovn
ovn: namespace ovn_prep ## installs the operator, also runs the prep step. Set OVN_IMG for custom image.
	$(eval $(call vars,$@,ovn))
	oc apply -f ${OPERATOR_DIR}

.PHONY: ovn_cleanup
ovn_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,ovn))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: ovn_deploy_prep
ovn_deploy_prep: export KIND=.*
ovn_deploy_prep: export IMAGE=unused
ovn_deploy_prep: ovn_deploy_cleanup ## prepares the CR to install the service based on the service sample file OVNAPI
	$(eval $(call vars,$@,ovn))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${OVN_BRANCH} ${OVN_REPO} && popd
	cp ${OVNDBS_CR} ${OVNNORTHD_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: ovn_deploy
ovn_deploy: ovn_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set OVN_REPO and OVN_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,ovn))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: ovn_deploy_cleanup
ovn_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,ovn))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/ovn-operator ${DEPLOY_DIR}

##@ OVS
.PHONY: ovs_prep
ovs_prep: export IMAGE=${OVS_IMG}
ovs_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,ovs))
	bash scripts/gen-olm.sh

.PHONY: ovs
ovs: namespace ovs_prep ## installs the operator, also runs the prep step. Set OVS_IMG for custom image.
	$(eval $(call vars,$@,ovs))
	oc apply -f ${OPERATOR_DIR}

.PHONY: ovs_cleanup
ovs_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,ovs))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: ovs_deploy_prep
ovs_deploy_prep: export KIND=.*
ovs_deploy_prep: export IMAGE=unused
ovs_deploy_prep: ovs_deploy_cleanup ## prepares the CR to install the service based on the service sample file OVS
	$(eval $(call vars,$@,ovs))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${OVS_BRANCH} ${OVS_REPO} && popd
	cp ${OVS_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: ovs_deploy
ovs_deploy: ovs_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set OVS_REPO and OVS_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,ovs))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: ovs_deploy_cleanup
ovs_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,ovs))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/ovs-operator ${DEPLOY_DIR}

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
	cp ${NEUTRONAPI_CR} ${DEPLOY_DIR}
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
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database neutron;" || true

##@ CINDER
.PHONY: cinder_prep
cinder_prep: export IMAGE=${CINDER_IMG}
cinder_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,cinder))
	bash scripts/gen-olm.sh

.PHONY: cinder
cinder: namespace cinder_prep ## installs the operator, also runs the prep step. Set CINDER_IMG for custom image.
	$(eval $(call vars,$@,cinder))
	oc apply -f ${OPERATOR_DIR}

.PHONY: cinder_cleanup
cinder_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,cinder))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: cinder_deploy_prep
cinder_deploy_prep: export KIND=Cinder
cinder_deploy_prep: export IMAGE=unused
cinder_deploy_prep: cinder_deploy_cleanup ## prepares the CR to install the service based on the service sample file CINDER
	$(eval $(call vars,$@,cinder))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${CINDER_BRANCH} ${CINDER_REPO} && popd
	cp ${CINDER_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: cinder_deploy
cinder_deploy: input cinder_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set CINDER_REPO and CINDER_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,cinder))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: cinder_deploy_cleanup
cinder_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,cinder))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/cinder-operator ${DEPLOY_DIR}
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database cinder;" || true

##@ RABBITMQ
.PHONY: rabbitmq_prep
rabbitmq_prep: export IMAGE=${RABBITMQ_IMG}
rabbitmq_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,cluster))
	bash scripts/gen-olm.sh

.PHONY: rabbitmq
rabbitmq: namespace rabbitmq_prep ## installs the operator, also runs the prep step. Set RABBITMQ_IMG for custom image.
	$(eval $(call vars,$@,cluster))
	oc apply -f ${OPERATOR_DIR}

.PHONY: rabbitmq_cleanup
rabbitmq_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,cluster))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: rabbitmq_deploy_prep
rabbitmq_deploy_prep: export KIND=RabbitmqCluster
rabbitmq_deploy_prep: rabbitmq_deploy_cleanup ## prepares the CR to install the service based on the service sample file RABBITMQ
	$(eval $(call vars,$@,rabbitmq))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${RABBITMQ_BRANCH} ${RABBITMQ_REPO} rabbitmq-operator && popd
	cp ${RABBITMQ_CR} ${DEPLOY_DIR}
	#bash scripts/gen-service-kustomize.sh

.PHONY: rabbitmq_deploy
rabbitmq_deploy: input rabbitmq_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set RABBITMQ_REPO and RABBITMQ_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,rabbitmq))
	KIND=RabbitmqCluster NAME=rabbitmq bash scripts/gen-name-kustomize.sh
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: rabbitmq_deploy_cleanup
rabbitmq_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,rabbitmq))
	oc delete --ignore-not-found=true RabbitmqCluster rabbitmq
	rm -Rf ${OPERATOR_BASE_DIR}/rabbitmq-operator ${DEPLOY_DIR}

##@ IRONIC
.PHONY: ironic_prep
ironic_prep: export IMAGE=${IRONIC_IMG}
ironic_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,ironic))
	bash scripts/gen-olm.sh

.PHONY: ironic
ironic: namespace ironic_prep ## installs the operator, also runs the prep step. Set IRONIC_IMG for custom image.
	$(eval $(call vars,$@,ironic))
	oc apply -f ${OPERATOR_DIR}

.PHONY: ironic_cleanup
ironic_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,ironic))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: ironic_deploy_prep
ironic_deploy_prep: export KIND=Ironic
ironic_deploy_prep: export IMAGE=${IRONIC_IMG}
ironic_deploy_prep: ironic_deploy_cleanup ## prepares the CR to install the service based on the service sample file IRONIC
	$(eval $(call vars,$@,ironic))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${IRONIC_BRANCH} ${IRONIC_REPO} && popd
	cp ${IRONIC_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: ironic_deploy
ironic_deploy: input ironic_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set IRONIC_REPO and IRONIC_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,ironic))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: ironic_deploy_cleanup
ironic_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,ironic))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/ironic-operator ${DEPLOY_DIR}
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database ironic;" || true

##@ OCTAVIA
.PHONY: octavia_prep
octavia_prep: export IMAGE=${OCTAVIA_IMG}
octavia_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,octavia))
	bash scripts/gen-olm.sh

.PHONY: octavia
octavia: namespace octavia_prep ## installs the operator, also runs the prep step. Set OCTAVIA_IMG for custom image.
	$(eval $(call vars,$@,octavia))
	oc apply -f ${OPERATOR_DIR}

.PHONY: octavia_cleanup
octavia_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,octavia))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: octavia_deploy_prep
octavia_deploy_prep: export KIND=OctaviaAPI
octavia_deploy_prep: export IMAGE="${OCTAVIAAPI_IMG}"
octavia_deploy_prep: octavia_deploy_cleanup ## prepares the CR to install the service based on the service sample file OCTAVIA
	$(eval $(call vars,$@,octavia))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${OCTAVIA_BRANCH} ${OCTAVIA_REPO} && popd
	cp ${OCTAVIAAPI_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: octavia_deploy
octavia_deploy: input octavia_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set OCTAVIA_REPO and OCTAVIA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,octavia))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: octavia_deploy_validate
octavia_deploy_validate: input namespace ## checks that octavia was properly deployed. Set OCTAVIA_KUTTL_DIR to use assert file from custom repo.
	kubectl-kuttl assert -n ${NAMESPACE} ${OCTAVIA_KUTTL_DIR}/../common/assert_sample_deployment.yaml --timeout 180

.PHONY: octavia_deploy_cleanup
octavia_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,octavia))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/octavia-operator ${DEPLOY_DIR}
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database octavia;" || true

##@ NOVA
.PHONY: nova_prep
nova_prep: export IMAGE=${NOVA_IMG}
nova_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,nova))
	bash scripts/gen-olm.sh

.PHONY: nova
nova: namespace nova_prep ## installs the operator, also runs the prep step. Set NOVA_IMG for custom image.
	$(eval $(call vars,$@,nova))
	oc apply -f ${OPERATOR_DIR}

.PHONY: nova_cleanup
nova_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,nova))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: nova_deploy_prep
nova_deploy_prep: export KIND=Nova
# TOOD(gibi): the tooling expect a containerImage at the top level
# but for projects like Cinder and Nova where there are multiple services with
# different images this customization does not make sense. Make this
# customization optional in the tooling.
nova_deploy_prep: export IMAGE=unused
nova_deploy_prep: nova_deploy_cleanup ## prepares the CR to install the service based on the service sample file NOVA
	$(eval $(call vars,$@,nova))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${NOVA_BRANCH} ${NOVA_REPO} && popd
	cp ${NOVA_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: nova_deploy
nova_deploy: input nova_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set NOVA_REPO and NOVA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,nova))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: nova_deploy_cleanup
nova_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,nova))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/nova-operator ${DEPLOY_DIR}
	oc rsh mariadb-openstack mysql -u root --password=${PASSWORD} -ss -e "show databases like 'nova_%';" | xargs -I '{}' oc rsh mariadb-openstack mysql -u root --password=${PASSWORD} -ss -e "drop database {};"

##@ KUTTL tests

.PHONY: mariadb_kuttl_run
mariadb_kuttl_run: ## runs kuttl tests for the mariadb operator, assumes that everything needed for running the test was deployed beforehand.
	INSTALL_YAMLS=${INSTALL_YAMLS} kubectl-kuttl test --config ${MARIADB_KUTTL_CONF} ${MARIADB_KUTTL_DIR}

.PHONY: mariadb_kuttl
mariadb_kuttl: namespace input openstack_crds deploy_cleanup mariadb_deploy_prep mariadb  ## runs kuttl tests for the mariadb operator. Installs openstack crds and keystone operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make mariadb_kuttl_run
	make deploy_cleanup
	make mariadb_cleanup

.PHONY: keystone_kuttl_run
keystone_kuttl_run: ## runs kuttl tests for the keystone operator, assumes that everything needed for running the test was deployed beforehand.
	INSTALL_YAMLS=${INSTALL_YAMLS} kubectl-kuttl test --config ${KEYSTONE_KUTTL_CONF} ${KEYSTONE_KUTTL_DIR}

.PHONY: keystone_kuttl
keystone_kuttl: namespace input openstack_crds deploy_cleanup mariadb mariadb_deploy mariadb_deploy_validate keystone_deploy_prep keystone ## runs kuttl tests for the keystone operator. Installs openstack crds and keystone operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make keystone_kuttl_run
	make deploy_cleanup
	make keystone_cleanup
	make mariadb_cleanup

.PHONY: octavia_kuttl_run
octavia_kuttl_run: ## runs kuttl tests for the octavia operator, assumes that everything needed for running the test was deployed beforehand.
	INSTALL_YAMLS=${INSTALL_YAMLS} kubectl-kuttl test --config ${OCTAVIA_KUTTL_CONF} ${OCTAVIA_KUTTL_DIR}

.PHONY: octavia_kuttl
octavia_kuttl: namespace input openstack_crds deploy_cleanup mariadb mariadb_deploy keystone octavia_deploy_prep octavia keystone_deploy mariadb_deploy_validate ## runs kuttl tests for the octavia operator. Installs openstack crds and mariadb, keystone, octavia operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make octavia_kuttl_run
	make deploy_cleanup
	make octavia_cleanup
	make keystone_cleanup
	make mariadb_cleanup

.PHONY: ovn_kuttl_run
ovn_kuttl_run: ## runs kuttl tests for the ovn operator, assumes that everything needed for running the test was deployed beforehand.
	INSTALL_YAMLS=${INSTALL_YAMLS} kubectl-kuttl test --config ${OVN_KUTTL_CONF} ${OVN_KUTTL_DIR}

.PHONY: ovn_kuttl
ovn_kuttl: namespace input openstack_crds deploy_cleanup ovn_deploy_prep ovn ## runs kuttl tests for the ovn operator. Installs openstack crds and ovn operator and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make ovn_kuttl_run
	make deploy_cleanup
	make ovn_cleanup
.PHONY: ironic_kuttl_run
ironic_kuttl_run: ## runs kuttl tests for the ironic operator, assumes that everything needed for running the test was deployed beforehand.
	INSTALL_YAMLS=${INSTALL_YAMLS} kubectl-kuttl test --config ${IRONIC_KUTTL_CONF} ${IRONIC_KUTTL_DIR}

.PHONY: ironic_kuttl
ironic_kuttl: namespace input openstack_crds deploy_cleanup mariadb mariadb_deploy keystone ironic_deploy_prep ironic keystone_deploy mariadb_deploy_validate ## runs kuttl tests for the ironic operator. Installs openstack crds and keystone operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make ironic_kuttl_run
	make deploy_cleanup
	make ironic_cleanup
	make keystone_cleanup
	make mariadb_cleanup

##@ ANSIBLEEE
.PHONY: ansibleee_prep
ansibleee_prep: export IMAGE=${ANSIBLEEE_IMG}
ansibleee_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,openstack-ansibleee))
	bash scripts/gen-olm.sh

.PHONY: ansibleee
ansibleee: namespace ansibleee_prep ## installs the operator, also runs the prep step. Set ansibleee_IMG for custom image.
	$(eval $(call vars,$@,openstack-ansibleee))
	oc apply -f ${OPERATOR_DIR}

.PHONY: ansibleee_cleanup
ansibleee_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,openstack-ansibleee))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

##@ CEPH
.PHONY: ceph
ceph: export IMAGE=${CEPH_IMG}
ceph: namespace ## deploy the Ceph Pod
	$(eval $(call vars,$@,ceph))
	bash scripts/gen-ceph-kustomize.sh "build"
	oc kustomize ${DEPLOY_DIR} | oc apply -f -
	bash scripts/gen-ceph-kustomize.sh "isready"
	bash scripts/gen-ceph-kustomize.sh "pools"
	bash scripts/gen-ceph-kustomize.sh "secret"

.PHONY: ceph_cleanup
ceph_cleanup: ## deletes the ceph pod
	$(eval $(call vars,$@,ceph))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${DEPLOY_DIR}
