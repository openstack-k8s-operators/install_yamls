# general
SHELL := /bin/bash
NAMESPACE                ?= openstack
PASSWORD                 ?= 12345678
SECRET                   ?= osp-secret
OUT                      ?= ${PWD}/out
METADATA_SHARED_SECRET   ?= 1234567842
HEAT_AUTH_ENCRYPTION_KEY ?= 767c3ed056cbaa3b9dfedb8c6f825bf0
CLEANUP_DIR_CMD					 ?= rm -Rf

# are we deploying to microshift
MICROSHIFT ?= 0

# operators gets cloned here
OPERATOR_BASE_DIR   ?= ${OUT}/operator

# storage (used by some operators)
STORAGE_CLASS       ?= "local-storage"

# network isolation
NETWORK_ISOLATION   ?= true

# options to pass in all targets that use git clone
GIT_CLONE_OPTS      ?=

# OpenStack Operator
OPENSTACK_IMG                ?= quay.io/openstack-k8s-operators/openstack-operator-index:latest
OPENSTACK_REPO               ?= https://github.com/openstack-k8s-operators/openstack-operator.git
OPENSTACK_BRANCH             ?= master
OPENSTACK_CTLPLANE           ?= $(if $(findstring true,$(NETWORK_ISOLATION)),config/samples/core_v1beta1_openstackcontrolplane_network_isolation.yaml,config/samples/core_v1beta1_openstackcontrolplane.yaml)
OPENSTACK_CR                 ?= ${OPERATOR_BASE_DIR}/openstack-operator/${OPENSTACK_CTLPLANE}
OPENSTACK_BUNDLE_IMG         ?= quay.io/openstack-k8s-operators/openstack-operator-bundle:latest
OPENSTACK_STORAGE_BUNDLE_IMG ?= quay.io/openstack-k8s-operators/openstack-operator-storage-bundle:latest
OPENSTACK_CRDS_DIR           ?= openstack_crds

# Infra Operator
INFRA_IMG           ?= quay.io/openstack-k8s-operators/infra-operator-index:latest
INFRA_REPO          ?= https://github.com/openstack-k8s-operators/infra-operator.git
INFRA_BRANCH        ?= master

# Memcached
# MEMCACHED_IMG     ?= (tis is unused because this is part of infra operator)
MEMCACHED           ?= config/samples/memcached_v1beta1_memcached.yaml
MEMCACHED_CR        ?= ${OPERATOR_BASE_DIR}/infra-operator/${MEMCACHED}
MEMCACHED_DEPL_IMG  ?= unused

# Keystone
KEYSTONE_IMG             ?= quay.io/openstack-k8s-operators/keystone-operator-index:latest
KEYSTONE_REPO            ?= https://github.com/openstack-k8s-operators/keystone-operator.git
KEYSTONE_BRANCH          ?= master
KEYSTONEAPI              ?= config/samples/keystone_v1beta1_keystoneapi.yaml
KEYSTONEAPI_CR           ?= ${OPERATOR_BASE_DIR}/keystone-operator/${KEYSTONEAPI}
KEYSTONEAPI_DEPL_IMG     ?= unused
KEYSTONE_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/keystone-operator/kuttl-test.yaml
KEYSTONE_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/keystone-operator/tests/kuttl/tests
KEYSTONE_KUTTL_NAMESPACE ?= keystone-kuttl-tests

# Mariadb
MARIADB_IMG         ?= quay.io/openstack-k8s-operators/mariadb-operator-index:latest
MARIADB_REPO        ?= https://github.com/openstack-k8s-operators/mariadb-operator.git
MARIADB_BRANCH      ?= master
MARIADB             ?= config/samples/mariadb_v1beta1_mariadb.yaml
MARIADB_CR          ?= ${OPERATOR_BASE_DIR}/mariadb-operator/${MARIADB}
MARIADB_DEPL_IMG    ?= unused
MARIADB_KUTTL_CONF  ?= ${OPERATOR_BASE_DIR}/mariadb-operator/kuttl-test.yaml
MARIADB_KUTTL_DIR   ?= ${OPERATOR_BASE_DIR}/mariadb-operator/tests/kuttl/tests

# Placement
PLACEMENT_IMG         ?= quay.io/openstack-k8s-operators/placement-operator-index:latest
PLACEMENT_REPO        ?= https://github.com/openstack-k8s-operators/placement-operator.git
PLACEMENT_BRANCH      ?= master
PLACEMENTAPI          ?= config/samples/placement_v1beta1_placementapi.yaml
PLACEMENTAPI_CR       ?= ${OPERATOR_BASE_DIR}/placement-operator/${PLACEMENTAPI}
PLACEMENTAPI_DEPL_IMG ?= unused

# Sir Glancealot
GLANCE_IMG          ?= quay.io/openstack-k8s-operators/glance-operator-index:latest
GLANCE_REPO         ?= https://github.com/openstack-k8s-operators/glance-operator.git
GLANCE_BRANCH       ?= master
GLANCE              ?= config/samples/glance_v1beta1_glance.yaml
GLANCE_CR           ?= ${OPERATOR_BASE_DIR}/glance-operator/${GLANCE}
GLANCEAPI_DEPL_IMG  ?= unused
GLANCE_KUTTL_CONF   ?= ${OPERATOR_BASE_DIR}/glance-operator/kuttl-test.yaml
GLANCE_KUTTL_DIR    ?= ${OPERATOR_BASE_DIR}/glance-operator/tests/kuttl/tests

# Ovn
OVN_IMG             ?= quay.io/openstack-k8s-operators/ovn-operator-index:latest
OVN_REPO            ?= https://github.com/openstack-k8s-operators/ovn-operator.git
OVN_BRANCH          ?= main
OVNDBS              ?= config/samples/ovn_v1beta1_ovndbcluster.yaml
OVNDBS_CR           ?= ${OPERATOR_BASE_DIR}/ovn-operator/${OVNDBS}
OVNNORTHD           ?= config/samples/ovn_v1beta1_ovnnorthd.yaml
OVNNORTHD_CR        ?= ${OPERATOR_BASE_DIR}/ovn-operator/${OVNNORTHD}
# TODO: Image customizations for all OVN services
OVN_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/ovn-operator/kuttl-test.yaml
OVN_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/ovn-operator/tests/kuttl/tests

# Ovs
OVS_IMG             ?= quay.io/openstack-k8s-operators/ovs-operator-index:latest
OVS_REPO            ?= https://github.com/openstack-k8s-operators/ovs-operator.git
OVS_BRANCH          ?= main
OVS                 ?= config/samples/ovs_v1beta1_ovs.yaml
OVS_CR              ?= ${OPERATOR_BASE_DIR}/ovs-operator/${OVS}
# TODO: Image customizations for all OVS services
OVS_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/ovs-operator/kuttl-test.yaml
OVS_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/ovs-operator/tests/kuttl/tests

# Neutron
NEUTRON_IMG         ?= quay.io/openstack-k8s-operators/neutron-operator-index:latest
NEUTRON_REPO        ?= https://github.com/openstack-k8s-operators/neutron-operator.git
NEUTRON_BRANCH      ?= master
NEUTRONAPI          ?= config/samples/neutron_v1beta1_neutronapi.yaml
NEUTRONAPI_CR       ?= ${OPERATOR_BASE_DIR}/neutron-operator/${NEUTRONAPI}
NEUTRONAPI_DEPL_IMG ?= unused
# TODO: Do we need interfaces to customize images for the other services ?
NEUTRON_KUTTL_CONF  ?= ${OPERATOR_BASE_DIR}/neutron-operator/kuttl-test.yaml
NEUTRON_KUTTL_DIR   ?= ${OPERATOR_BASE_DIR}/neutron-operator/test/kuttl/tests

# Cinder
CINDER_IMG          ?= quay.io/openstack-k8s-operators/cinder-operator-index:latest
CINDER_REPO         ?= https://github.com/openstack-k8s-operators/cinder-operator.git
CINDER_BRANCH       ?= master
CINDER              ?= config/samples/cinder_v1beta1_cinder.yaml
CINDER_CR           ?= ${OPERATOR_BASE_DIR}/cinder-operator/${CINDER}
# TODO: Image customizations for all Cinder services
CINDER_KUTTL_CONF   ?= ${OPERATOR_BASE_DIR}/cinder-operator/kuttl-test.yaml
CINDER_KUTTL_DIR    ?= ${OPERATOR_BASE_DIR}/cinder-operator/tests/kuttl/tests

# RabbitMQ
RABBITMQ_IMG        ?= quay.io/openstack-k8s-operators/rabbitmq-cluster-operator-index:latest
RABBITMQ_REPO       ?= https://github.com/openstack-k8s-operators/rabbitmq-cluster-operator.git
RABBITMQ_BRANCH     ?= patches
RABBITMQ            ?= docs/examples/default-security-context/rabbitmq.yaml
RABBITMQ_CR         ?= ${OPERATOR_BASE_DIR}/rabbitmq-operator/${RABBITMQ}
# TODO: Image customizations for all RabbitMQ services

# Ironic
IRONIC_IMG          ?= quay.io/openstack-k8s-operators/ironic-operator-index:latest
IRONIC_REPO         ?= https://github.com/openstack-k8s-operators/ironic-operator.git
IRONIC_BRANCH       ?= master
IRONIC              ?= config/samples/ironic_v1beta1_ironic.yaml
IRONIC_CR           ?= ${OPERATOR_BASE_DIR}/ironic-operator/${IRONIC}
IRONICAPI_DEPL_IMG  ?= unused
IRONICCON_DEPL_IMG  ?= unused
IRONICPXE_DEPL_IMG  ?= unused
IRONICINS_DEPL_IMG  ?= unused
IRONICNAG_DEPL_IMG  ?= unused
IRONIC_KUTTL_CONF   ?= ${OPERATOR_BASE_DIR}/ironic-operator/kuttl-test.yaml
IRONIC_KUTTL_DIR    ?= ${OPERATOR_BASE_DIR}/ironic-operator/tests/kuttl/tests

# Octavia
OCTAVIA_IMG         ?= quay.io/openstack-k8s-operators/octavia-operator-index:latest
OCTAVIA_REPO        ?= https://github.com/openstack-k8s-operators/octavia-operator.git
OCTAVIA_BRANCH      ?= main
OCTAVIA             ?= config/samples/octavia_v1beta1_octavia.yaml
OCTAVIA_CR          ?= ${OPERATOR_BASE_DIR}/octavia-operator/${OCTAVIA}
# TODO: Image customizations for all Octavia services
OCTAVIA_KUTTL_CONF  ?= ${OPERATOR_BASE_DIR}/octavia-operator/kuttl-test.yaml
OCTAVIA_KUTTL_DIR   ?= ${OPERATOR_BASE_DIR}/octavia-operator/tests/kuttl/tests

# Nova
NOVA_IMG            ?= quay.io/openstack-k8s-operators/nova-operator-index:latest
NOVA_REPO           ?= https://github.com/openstack-k8s-operators/nova-operator.git
NOVA_BRANCH         ?= master
# NOTE(gibi): We intentionally not using the default nova sample here
# as that would require two RabbitMQCluster to be deployed which a) is not what
# the make rabbitmq_deploy target does ii) required extra resource in the dev
# environment.
NOVA                ?= config/samples/nova_v1beta1_nova_collapsed_cell.yaml
NOVA_CR             ?= ${OPERATOR_BASE_DIR}/nova-operator/${NOVA}
# TODO: Image customizations for all Nova services

# Horizon
HORIZON_IMG         ?= quay.io/openstack-k8s-operators/horizon-operator-index:latest
HORIZON_REPO        ?= https://github.com/openstack-k8s-operators/horizon-operator.git
HORIZON_BRANCH      ?= main
HORIZON             ?= config/samples/horizon_v1beta1_horizon.yaml
HORIZON_CR          ?= ${OPERATOR_BASE_DIR}/horizon-operator/${HORIZON}
HORIZON_DEPL_IMG    ?= unused

# Heat
HEAT_IMG            ?= quay.io/openstack-k8s-operators/heat-operator-index:latest
HEAT_REPO           ?= https://github.com/openstack-k8s-operators/heat-operator.git
HEAT_BRANCH         ?= main
HEAT                ?= config/samples/heat_v1beta1_heat.yaml
HEAT_CR             ?= ${OPERATOR_BASE_DIR}/heat-operator/${HEAT}
HEATAPI_DEPL_IMG    ?= unused
HEATENGINE_DEPL_IMG ?= unused
HEAT_KUTTL_CONF     ?= ${OPERATOR_BASE_DIR}/heat-operator/kuttl-test.yaml
HEAT_KUTTL_DIR      ?= ${OPERATOR_BASE_DIR}/heat-operator/tests/kuttl/tests

# AnsibleEE
ANSIBLEEE_IMG        ?= quay.io/openstack-k8s-operators/openstack-ansibleee-operator-index:latest
ANSIBLEEE_REPO       ?= https://github.com/openstack-k8s-operators/openstack-ansibleee-operator
ANSIBLEEE_BRANCH     ?= main
ANSIBLEEE            ?= config/samples/_v1alpha1_ansibleee.yaml
ANSIBLEEE_CR         ?= ${OPERATOR_BASE_DIR}/openstack-ansibleee-operator/${ANSIBLEEE}
ANSIBLEEE_KUTTL_CONF ?= ${OPERATOR_BASE_DIR}/openstack-ansibleee-operator/kuttl-test.yaml
ANSIBLEEE_KUTTL_DIR  ?= ${OPERATOR_BASE_DIR}/openstack-ansibleee-operator/tests/kuttl/tests


# Baremetal Operator
BAREMETAL_IMG       ?= quay.io/openstack-k8s-operators/openstack-baremetal-operator-index:latest
BAREMETAL_REPO      ?= https://github.com/openstack-k8s-operators/openstack-baremetal-operator.git
BAREMETAL_BRANCH    ?= main

# Dataplane Operator
DATAPLANE_IMG                                    ?= quay.io/openstack-k8s-operators/dataplane-operator-index:latest
DATAPLANE_REPO                                   ?= https://github.com/openstack-k8s-operators/dataplane-operator.git
DATAPLANE_BRANCH                                 ?= main
OPENSTACK_DATAPLANE                              ?= config/samples/dataplane_v1beta1_openstackdataplane.yaml
DATAPLANE_CR                                     ?= ${OPERATOR_BASE_DIR}/dataplane-operator/${OPENSTACK_DATAPLANE}
DATAPLANE_ANSIBLE_SECRET                         ?=dataplane-ansible-ssh-private-key-secret
DATAPLANE_COMPUTE_IP                             ?=192.168.122.100
DATAPLANE_COMPUTE_1_IP                           ?=192.168.122.101
DATAPLANE_RUNNER_IMG                             ?=quay.io/openstack-k8s-operators/openstack-ansibleee-runner:latest
DATAPLANE_NETWORK_CONFIG_TEMPLATE                ?=templates/single_nic_vlans/single_nic_vlans.j2
DATAPLANE_SSHD_ALLOWED_RANGES                    ?=['192.168.122.0/24']
DATAPLANE_CHRONY_NTP_SERVER                      ?=pool.ntp.org
DATAPLANE_DNS_SERVER                             ?=192.168.122.1
DATAPLANE_OVN_METADATA_AGENT_BIND_HOST           ?=127.0.0.1
DATAPLANE_SINGLE_NODE                            ?=true
DATAPLANE_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/dataplane-operator/kuttl-test.yaml
DATAPLANE_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/dataplane-operator/tests/kuttl/tests
DATAPLANE_KUTTL_NAMESPACE ?= dataplane-kuttl-tests

# Manila
MANILA_IMG          ?= quay.io/openstack-k8s-operators/manila-operator-index:latest
MANILA_REPO         ?= https://github.com/openstack-k8s-operators/manila-operator.git
MANILA_BRANCH       ?= main
MANILA              ?= config/samples/manila_v1beta1_manila.yaml
MANILA_CR           ?= ${OPERATOR_BASE_DIR}/manila-operator/${MANILA}
# TODO: Image customizations for all Manila services

# Ceph
CEPH_IMG            ?= quay.io/ceph/demo:latest

# NNCP
NNCP_INTERFACE      ?= enp6s0

# Telemetry
TELEMETRY_IMG                    ?= quay.io/openstack-k8s-operators/telemetry-operator-index:latest
TELEMETRY_REPO                   ?= https://github.com/openstack-k8s-operators/telemetry-operator.git
TELEMETRY_BRANCH                 ?= main
TELEMETRY                        ?= config/samples/telemetry_v1beta1_telemetry.yaml
TELEMETRY_CR                     ?= ${OPERATOR_BASE_DIR}/telemetry-operator/${TELEMETRY}
CEILOMETER_CENTRAL_DEPL_IMG      ?= unused
CEILOMETER_NOTIFICATION_DEPL_IMG ?= unused
SG_CORE_DEPL_IMG                 ?= unused

# BMO
BMO_REPO                         ?= https://github.com/metal3-io/baremetal-operator
BMO_BRANCH                       ?= main
CERTMANAGER_URL                  ?= https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml
PROVISIONING_INTERFACE           ?= enp2s0
IRONIC_HOST                      ?= 192.168.130.11

# Swift
SWIFT_IMG        ?= quay.io/openstack-k8s-operators/swift-operator-index:latest
SWIFT_REPO       ?= https://github.com/openstack-k8s-operators/swift-operator.git
SWIFT_BRANCH     ?= main
SWIFTRING        ?= config/samples/swift_v1beta1_swiftring.yaml
SWIFTRING_CR     ?= ${OPERATOR_BASE_DIR}/swift-operator/${SWIFTRING}
SWIFTPROXY       ?= config/samples/swift_v1beta1_swiftproxy.yaml
SWIFTPROXY_CR    ?= ${OPERATOR_BASE_DIR}/swift-operator/${SWIFTPROXY}
SWIFTSTORAGE     ?= config/samples/swift_v1beta1_swiftstorage.yaml
SWIFTSTORAGE_CR  ?= ${OPERATOR_BASE_DIR}/swift-operator/${SWIFTSTORAGE}

# target vars for generic operator install info 1: target name , 2: operator name
define vars
${1}: export NAMESPACE=${NAMESPACE}
${1}: export SECRET=${SECRET}
${1}: export PASSWORD=${PASSWORD}
${1}: export METADATA_SHARED_SECRET=${METADATA_SHARED_SECRET}
${1}: export HEAT_AUTH_ENCRYPTION_KEY=${HEAT_AUTH_ENCRYPTION_KEY}
${1}: export STORAGE_CLASS=${STORAGE_CLASS}
${1}: export OUT=${OUT}
${1}: export CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD}
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
cleanup: heat_cleanup horizon_cleanup nova_cleanup octavia_cleanup neutron_cleanup ovn_cleanup ironic_cleanup cinder_cleanup glance_cleanup placement_cleanup keystone_cleanup mariadb_cleanup telemetry_cleanup ## Delete all operators

.PHONY: deploy_cleanup
deploy_cleanup: heat_deploy_cleanup horizon_deploy_cleanup nova_deploy_cleanup octavia_deploy_cleanup neutron_deploy_cleanup ovn_deploy_cleanup ovs_deploy_cleanup ironic_deploy_cleanup cinder_deploy_cleanup glance_deploy_cleanup placement_deploy_cleanup keystone_deploy_cleanup mariadb_deploy_cleanup telemetry_deploy_cleanup ## Delete all OpenStack service objects

.PHONY: wait
wait: ## wait for an operator's controller-manager pod to be ready (requires OPERATOR_NAME to be explicitly passed!)
	$(eval $(call vars,$@,$(value OPERATOR_NAME)))
	bash scripts/operator-wait.sh

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
	if oc get pv | grep ${STORAGE_CLASS}; then oc get pv | grep ${STORAGE_CLASS} | cut -f 1 -d ' ' | xargs oc delete pv; fi
	if oc get sc ${STORAGE_CLASS}; then oc delete sc ${STORAGE_CLASS}; fi
	bash scripts/delete-pv.sh

##@ NAMESPACE
.PHONY: namespace
namespace: ## creates the namespace specified via NAMESPACE env var (defaults to openstack)
	$(eval $(call vars,$@))
	bash scripts/gen-namespace.sh
	oc apply -f ${OUT}/${NAMESPACE}/namespace.yaml
	sleep 2
ifeq ($(MICROSHIFT) ,0)
	oc project ${NAMESPACE}
else
	oc config set-context --current --namespace=${NAMESPACE}
	oc adm policy add-scc-to-user privileged -z default --namespace ${NAMESPACE}
endif

.PHONY: namespace_cleanup
namespace_cleanup: ## deletes the namespace specified via NAMESPACE env var, also runs cleanup for all services to cleanup the namespace prior delete it.
	$(eval $(call vars,$@))
	make keystone_cleanup
	make mariadb_cleanup
	oc delete project ${NAMESPACE}
	${CLEANUP_DIR_CMD} ${OUT}/${NAMESPACE}

##@ SERVICE INPUT
.PHONY: input
input: namespace ## creates required secret/CM, used by the services as input
	$(eval $(call vars,$@))
	bash scripts/gen-input-kustomize.sh
	oc get secret/${SECRET} || oc kustomize ${OUT}/${NAMESPACE}/input | oc apply -f -

.PHONY: input_cleanup
input_cleanup: ## deletes the secret/CM, used by the services as input
	oc kustomize ${OUT}/${NAMESPACE}/input | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OUT}/${NAMESPACE}/input

##@ CRC BMO SETUP
.PHONY: crc_bmo_setup
crc_bmo_setup: export IRONIC_HOST_IP=${IRONIC_HOST}
crc_bmo_setup:
	$(eval $(call vars,$@))
	mkdir -p ${OPERATOR_BASE_DIR}
	oc apply -f ${CERTMANAGER_URL}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(BMO_BRANCH),-b ${BMO_BRANCH}) ${BMO_REPO} "baremetal-operator" && popd
	pushd ${OPERATOR_BASE_DIR}/baremetal-operator && sed -i 's/eth2/${PROVISIONING_INTERFACE}/g' ironic-deployment/default/ironic_bmo_configmap.env && popd
	pushd ${OPERATOR_BASE_DIR}/baremetal-operator && make generate manifests && bash tools/deploy.sh -b -i && popd
	## Hack to add required scc
	oc adm policy add-scc-to-user privileged system:serviceaccount:baremetal-operator-system:baremetal-operator-controller-manager
	oc adm policy add-scc-to-user privileged system:serviceaccount:baremetal-operator-system:default

##@ CRC BMO CLEANUP
.PHONY: crc_bmo_cleanup
crc_bmo_cleanup:
	oc kustomize ${OPERATOR_BASE_DIR}/baremetal-operator/ironic-deployment/default | oc delete --ignore-not-found=true -f -
	oc kustomize ${OPERATOR_BASE_DIR}/baremetal-operator/config | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/baremetal-operator

BMO_CRDS=$(shell oc get crds | grep metal3.io)
ifeq (,$(findstring baremetalhosts.metal3.io, ${BMO_CRDS}))
	BMO_SETUP ?= true
endif

##@ OPENSTACK
.PHONY: openstack_prep
openstack_prep: export IMAGE=${OPENSTACK_IMG}
openstack_prep: $(if $(findstring true,$(NETWORK_ISOLATION)), nmstate nncp netattach metallb metallb_config) ## creates the files to install the operator using olm
openstack_prep: $(if $(findstring true, $(BMO_SETUP)), crc_bmo_setup) ## Setup BMO
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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}
	oc delete subscription openstack-storage-operators-alpha-openstack-operator-index-openstack --ignore-not-found=true
	oc delete csv openstack-storage-operators.v0.0.1 --ignore-not-found=true

.PHONY: openstack_deploy_prep
openstack_deploy_prep: export KIND=OpenStackControlPlane
openstack_deploy_prep: openstack_deploy_cleanup $(if $(findstring true,$(NETWORK_ISOLATION)), nmstate nncp netattach metallb metallb_config)  ## prepares the CR to install the service based on the service sample file OPENSTACK
	$(eval $(call vars,$@,openstack))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(OPENSTACK_BRANCH),-b ${OPENSTACK_BRANCH}) ${OPENSTACK_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${OPENSTACK_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: openstack_deploy
openstack_deploy: input openstack_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set OPENSTACK_REPO and OPENSTACK_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,openstack))
	bash scripts/operator-deploy-resources.sh

.PHONY: openstack_deploy_cleanup
openstack_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,openstack))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/openstack-operator ${DEPLOY_DIR}

.PHONY: edpm_deploy_prep
edpm_deploy_prep: export KIND=OpenStackDataPlane
edpm_deploy_prep: export EDPM_ANSIBLE_SECRET=${DATAPLANE_ANSIBLE_SECRET}
edpm_deploy_prep: export EDPM_SINGLE_NODE=${DATAPLANE_SINGLE_NODE}
edpm_deploy_prep: export EDPM_COMPUTE_IP=${DATAPLANE_COMPUTE_IP}
edpm_deploy_prep: export EDPM_COMPUTE_1_IP=${DATAPLANE_COMPUTE_1_IP}
edpm_deploy_prep: export OPENSTACK_RUNNER_IMG=${DATAPLANE_RUNNER_IMG}
edpm_deploy_prep: export EDPM_NETWORK_CONFIG_TEMPLATE=${DATAPLANE_NETWORK_CONFIG_TEMPLATE}
edpm_deploy_prep: export EDPM_SSHD_ALLOWED_RANGES=${DATAPLANE_SSHD_ALLOWED_RANGES}
edpm_deploy_prep: export EDPM_CHRONY_NTP_SERVER=${DATAPLANE_CHRONY_NTP_SERVER}
edpm_deploy_prep: export EDPM_DNS_SERVER=${DATAPLANE_DNS_SERVER}
edpm_deploy_prep: export EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST=$(shell oc get svc nova-metadata-internal -o json |jq -r '.status.loadBalancer.ingress[0].ip')
edpm_deploy_prep: export EDPM_OVN_METADATA_AGENT_PROXY_SHARED_SECRET=${METADATA_SHARED_SECRET}
edpm_deploy_prep: export EDPM_OVN_METADATA_AGENT_BIND_HOST=${DATAPLANE_OVN_METADATA_AGENT_BIND_HOST}
edpm_deploy_prep: export EDPM_OVN_METADATA_AGENT_TRANSPORT_URL=$(shell oc get secret rabbitmq-transport-url-neutron-neutron-transport -o json | jq -r .data.transport_url | base64 -d)
edpm_deploy_prep: export EDPM_OVN_METADATA_AGENT_SB_CONNECTION=$(shell oc get ovndbcluster ovndbcluster-sb -o json | jq -r .status.dbAddress)
edpm_deploy_prep: export EDPM_OVN_DBS=$(shell oc get ovndbcluster ovndbcluster-sb -o json | jq -r '.status.networkAttachments."openstack/internalapi"[0]')
edpm_deploy_prep: export EDPM_NADS=$(shell oc get network-attachment-definitions -o json | jq -r "[.items[].metadata.name]")
edpm_deploy_prep: edpm_deploy_cleanup $(if $(findstring true,$(NETWORK_ISOLATION)), nmstate nncp netattach metallb metallb_config) ## prepares the CR to install the data plane
	$(eval $(call vars,$@,dataplane))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(DATAPLANE_BRANCH),-b ${DATAPLANE_BRANCH}) ${DATAPLANE_REPO} "${OPERATOR_NAME}-operator" && popd
	oc apply -f ${OPERATOR_BASE_DIR}/${OPERATOR_NAME}-operator/config/services
	cp ${DATAPLANE_CR} ${DEPLOY_DIR}
	bash scripts/gen-edpm-kustomize.sh
	devsetup/scripts/gen-ansibleee-ssh-key.sh

.PHONY: edpm_deploy_cleanup
edpm_deploy_cleanup: ## cleans up the edpm instance, Does not affect the operator.
	$(eval $(call vars,$@,dataplane))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/dataplane-operator ${DEPLOY_DIR}

.PHONY: edpm_deploy
edpm_deploy: input edpm_deploy_prep ## installs the dataplane instance using kustomize. Runs prep step in advance. Set DATAPLANE_REPO and DATAPLANE_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,dataplane))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: openstack_crds
openstack_crds: ## installs all openstack CRDs. Useful for infrastructure dev
	mkdir -p ${OUT}/${OPENSTACK_CRDS_DIR}
	skopeo copy "docker://${OPENSTACK_BUNDLE_IMG}" dir:${OUT}/${OPENSTACK_CRDS_DIR}
	for X in $$(file ${OUT}/${OPENSTACK_CRDS_DIR}/* | grep gzip | cut -f 1 -d ':'); do tar xvf $$X -C ${OUT}/${OPENSTACK_CRDS_DIR}/; done
	for X in $$(grep -l CustomResourceDefinition ${OUT}/${OPENSTACK_CRDS_DIR}/manifests/*); do oc apply -f $$X; done

.PHONY: openstack_storage_crds
openstack_storage_crds: export OPENSTACK_BUNDLE_IMG=${OPENSTACK_STORAGE_BUNDLE_IMG}
openstack_storage_crds: export OPENSTACK_CRDS_DIR=openstack_storage_crds
openstack_storage_crds: ## installs storage openstack CRDs. Useful for infrastructure dev
	make openstack_crds

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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

##@ MEMCACHED
.PHONY: memcached_deploy_prep
memcached_deploy_prep: export KIND=Memcached
memcached_deploy_prep: export IMAGE=${MEMCACHED_DEPL_IMG}
memcached_deploy_prep: memcached_deploy_cleanup ## prepares the CR to install the service based on the service sample file MEMCACHED
	$(eval $(call vars,$@,infra))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(INFRA_BRANCH),-b ${INFRA_BRANCH}) ${INFRA_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${MEMCACHED_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: memcached_deploy
memcached_deploy: input memcached_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set INFRA_REPO and INFRA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,infra))
	bash scripts/operator-deploy-resources.sh

.PHONY: memcached_deploy_cleanup
memcached_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,infra))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/infra-operator ${DEPLOY_DIR}

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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: keystone_deploy_prep
keystone_deploy_prep: export KIND=KeystoneAPI
keystone_deploy_prep: export IMAGE=${KEYSTONEAPI_DEPL_IMG}
keystone_deploy_prep: keystone_deploy_cleanup ## prepares the CR to install the service based on the service sample file KEYSTONEAPI
	$(eval $(call vars,$@,keystone))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(KEYSTONE_BRANCH),-b ${KEYSTONE_BRANCH}) ${KEYSTONE_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${KEYSTONEAPI_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: keystone_deploy
keystone_deploy: input keystone_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set KEYSTONE_REPO and KEYSTONE_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,keystone))
	bash scripts/operator-deploy-resources.sh

.PHONY: keystone_deploy_validate
keystone_deploy_validate: input namespace ## checks that keystone was properly deployed. Set KEYSTONE_KUTTL_DIR to use assert file from custom repo.
	kubectl-kuttl assert -n ${NAMESPACE} ${KEYSTONE_KUTTL_DIR}/../common/assert_sample_deployment.yaml --timeout 180

.PHONY: keystone_deploy_cleanup
keystone_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,keystone))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/keystone-operator ${DEPLOY_DIR}
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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: mariadb_deploy_prep
mariadb_deploy_prep: export KIND=MariaDB
mariadb_deploy_prep: export IMAGE=${MARIADB_DEPL_IMG}
mariadb_deploy_prep: mariadb_deploy_cleanup ## prepares the CRs files to install the service based on the service sample file MARIADB
	$(eval $(call vars,$@,mariadb))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(MARIADB_BRANCH),-b ${MARIADB_BRANCH}) ${MARIADB_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${MARIADB_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: mariadb_deploy
mariadb_deploy: input mariadb_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set MARIADB_REPO and MARIADB_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,mariadb))
	bash scripts/operator-deploy-resources.sh

.PHONY: mariadb_deploy_validate
mariadb_deploy_validate: input namespace ## checks that mariadb was properly deployed. Set KEYSTONE_KUTTL_DIR to use assert file from custom repo.
	kubectl-kuttl assert -n ${NAMESPACE} ${MARIADB_KUTTL_DIR}/../common/assert_sample_deployment.yaml --timeout 180

.PHONY: mariadb_deploy_cleanup
mariadb_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,mariadb))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/mariadb-operator ${DEPLOY_DIR}

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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: placement_deploy_prep
placement_deploy_prep: export KIND=PlacementAPI
placement_deploy_prep: export IMAGE=${PLACEMENTAPI_DEPL_IMG}
placement_deploy_prep: placement_deploy_cleanup ## prepares the CR to install the service based on the service sample file PLACEMENTAPI
	$(eval $(call vars,$@,placement))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(PLACEMENT_BRANCH),-b ${PLACEMENT_BRANCH}) ${PLACEMENT_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${PLACEMENTAPI_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: placement_deploy
placement_deploy: input placement_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set PLACEMENT_REPO and PLACEMENT_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,placement))
	bash scripts/operator-deploy-resources.sh

.PHONY: placement_deploy_cleanup
placement_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,placement))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/placement-operator ${DEPLOY_DIR}
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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: glance_deploy_prep
glance_deploy_prep: export KIND=Glance
glance_deploy_prep: export IMAGE=${GLANCEAPI_DEPL_IMG},${GLANCEAPI_DEPL_IMG},${GLANCEAPI_DEPL_IMG}
glance_deploy_prep: export IMAGE_PATH=containerImage,glanceAPIInternal/containerImage,glanceAPIExternal/containerImage
glance_deploy_prep: glance_deploy_cleanup ## prepares the CR to install the service based on the service sample file GLANCE
	$(eval $(call vars,$@,glance))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(GLANCE_BRANCH),-b ${GLANCE_BRANCH}) ${GLANCE_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${GLANCE_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: glance_deploy
glance_deploy: input glance_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set GLANCE_REPO and GLANCE_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,glance))
	bash scripts/operator-deploy-resources.sh

.PHONY: glance_deploy_cleanup
glance_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,glance))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/glance-operator ${DEPLOY_DIR}
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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: ovn_deploy_prep
ovn_deploy_prep: export KIND=.*
ovn_deploy_prep: ovn_deploy_cleanup ## prepares the CR to install the service based on the service sample file OVNAPI
	$(eval $(call vars,$@,ovn))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(OVN_BRANCH),-b ${OVN_BRANCH}) ${OVN_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${OVNDBS_CR} ${OVNNORTHD_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: ovn_deploy
ovn_deploy: ovn_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set OVN_REPO and OVN_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,ovn))
	bash scripts/operator-deploy-resources.sh

.PHONY: ovn_deploy_cleanup
ovn_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,ovn))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/ovn-operator ${DEPLOY_DIR}

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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: ovs_deploy_prep
ovs_deploy_prep: export KIND=.*
ovs_deploy_prep: ovs_deploy_cleanup ## prepares the CR to install the service based on the service sample file OVS
	$(eval $(call vars,$@,ovs))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(OVS_BRANCH),-b ${OVS_BRANCH}) ${OVS_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${OVS_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: ovs_deploy
ovs_deploy: ovs_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set OVS_REPO and OVS_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,ovs))
	bash scripts/operator-deploy-resources.sh

.PHONY: ovs_deploy_cleanup
ovs_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,ovs))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/ovs-operator ${DEPLOY_DIR}

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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: neutron_deploy_prep
neutron_deploy_prep: export KIND=NeutronAPI
neutron_deploy_prep: export IMAGE=${NEUTRONAPI_DEPL_IMG}
neutron_deploy_prep: neutron_deploy_cleanup ## prepares the CR to install the service based on the service sample file NEUTRONAPI
	$(eval $(call vars,$@,neutron))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(NEUTRON_BRANCH),-b ${NEUTRON_BRANCH}) ${NEUTRON_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${NEUTRONAPI_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: neutron_deploy
neutron_deploy: input neutron_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set NEUTRON_REPO and NEUTRON_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,neutron))
	bash scripts/operator-deploy-resources.sh

.PHONY: neutron_deploy_cleanup
neutron_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,neutron))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/neutron-operator ${DEPLOY_DIR}
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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: cinder_deploy_prep
cinder_deploy_prep: export KIND=Cinder
cinder_deploy_prep: cinder_deploy_cleanup ## prepares the CR to install the service based on the service sample file CINDER
	$(eval $(call vars,$@,cinder))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(CINDER_BRANCH),-b ${CINDER_BRANCH}) ${CINDER_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${CINDER_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: cinder_deploy
cinder_deploy: input cinder_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set CINDER_REPO and CINDER_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,cinder))
	bash scripts/operator-deploy-resources.sh

.PHONY: cinder_deploy_validate
cinder_deploy_validate: input namespace ## checks that cinder was properly deployed. Set CINDER_KUTTL_DIR to use assert file from custom repo.
	kubectl-kuttl assert -n ${NAMESPACE} ${CINDER_KUTTL_DIR}/../common/assert_sample_deployment.yaml --timeout 180

.PHONY: cinder_deploy_cleanup
cinder_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,cinder))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/cinder-operator ${DEPLOY_DIR}
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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: rabbitmq_deploy_prep
rabbitmq_deploy_prep: export KIND=RabbitmqCluster
rabbitmq_deploy_prep: rabbitmq_deploy_cleanup ## prepares the CR to install the service based on the service sample file RABBITMQ
	$(eval $(call vars,$@,rabbitmq))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(RABBITMQ_BRANCH),-b ${RABBITMQ_BRANCH}) ${RABBITMQ_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${RABBITMQ_CR} ${DEPLOY_DIR}
	#bash scripts/gen-service-kustomize.sh

.PHONY: rabbitmq_deploy
rabbitmq_deploy: input rabbitmq_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set RABBITMQ_REPO and RABBITMQ_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,rabbitmq))
	KIND=RabbitmqCluster NAME=rabbitmq bash scripts/gen-name-kustomize.sh
	bash scripts/operator-deploy-resources.sh

.PHONY: rabbitmq_deploy_cleanup
rabbitmq_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,rabbitmq))
	oc delete --ignore-not-found=true RabbitmqCluster rabbitmq
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/rabbitmq-operator ${DEPLOY_DIR}

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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: ironic_deploy_prep
ironic_deploy_prep: export KIND=Ironic
ironic_deploy_prep: export IMAGE=${IRONICAPI_DEPL_IMG},${IRONICCON_DEPL_IMG},${IRONICPXE_DEPL_IMG},${IRONICINS_DEPL_IMG},${IRONICPXE_DEPL_IMG},${IRONICNAG_DEPL_IMG}
ironic_deploy_prep: export IMAGE_PATH=ironicAPI/containerImage,ironicConductors/0/containerImage,ironicConductors/0/pxeContainerImage,ironicInspector/containerImage,ironicInspector/pxeContainerImage,ironicNeutronAgent/containerImage
ironic_deploy_prep: ironic_deploy_cleanup ## prepares the CR to install the service based on the service sample file IRONIC
	$(eval $(call vars,$@,ironic))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(IRONIC_BRANCH),-b ${IRONIC_BRANCH}) ${IRONIC_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${IRONIC_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: ironic_deploy
ironic_deploy: input ironic_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set IRONIC_REPO and IRONIC_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,ironic))
	bash scripts/operator-deploy-resources.sh

.PHONY: ironic_deploy_cleanup
ironic_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,ironic))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/ironic-operator ${DEPLOY_DIR}
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database ironic;" || true
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database ironic_inspector;" || true

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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: octavia_deploy_prep
octavia_deploy_prep: export KIND=Octavia
octavia_deploy_prep: octavia_deploy_cleanup ## prepares the CR to install the service based on the service sample file OCTAVIA
	$(eval $(call vars,$@,octavia))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(OCTAVIA_BRANCH),-b ${OCTAVIA_BRANCH}) ${OCTAVIA_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${OCTAVIA_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: octavia_deploy
octavia_deploy: input octavia_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set OCTAVIA_REPO and OCTAVIA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,octavia))
	bash scripts/operator-deploy-resources.sh

.PHONY: octavia_deploy_validate
octavia_deploy_validate: input namespace ## checks that octavia was properly deployed. Set OCTAVIA_KUTTL_DIR to use assert file from custom repo.
	kubectl-kuttl assert -n ${NAMESPACE} ${OCTAVIA_KUTTL_DIR}/../common/assert_sample_deployment.yaml --timeout 180

.PHONY: octavia_deploy_cleanup
octavia_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,octavia))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/octavia-operator ${DEPLOY_DIR}
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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: nova_deploy_prep
nova_deploy_prep: export KIND=Nova
# TOOD(gibi): the tooling expect a containerImage at the top level
# but for projects like Cinder and Nova where there are multiple services with
# different images this customization does not make sense. Make this
# customization optional in the tooling.
nova_deploy_prep: nova_deploy_cleanup ## prepares the CR to install the service based on the service sample file NOVA
	$(eval $(call vars,$@,nova))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(NOVA_BRANCH),-b ${NOVA_BRANCH}) ${NOVA_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${NOVA_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: nova_deploy
nova_deploy: input nova_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set NOVA_REPO and NOVA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,nova))
	bash scripts/operator-deploy-resources.sh

.PHONY: nova_deploy_cleanup
nova_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,nova))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/nova-operator ${DEPLOY_DIR}
	oc rsh mariadb-openstack mysql -u root --password=${PASSWORD} -ss -e "show databases like 'nova_%';" | xargs -I '{}' oc rsh mariadb-openstack mysql -u root --password=${PASSWORD} -ss -e "drop database {};"

##@ KUTTL tests

.PHONY: mariadb_kuttl_run
mariadb_kuttl_run: ## runs kuttl tests for the mariadb operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${MARIADB_KUTTL_CONF} ${MARIADB_KUTTL_DIR}

.PHONY: mariadb_kuttl
mariadb_kuttl: namespace input openstack_crds deploy_cleanup mariadb_deploy_prep mariadb  ## runs kuttl tests for the mariadb operator. Installs openstack crds and keystone operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make mariadb_kuttl_run
	make deploy_cleanup
	make mariadb_cleanup

.PHONY: keystone_kuttl_run
keystone_kuttl_run: ## runs kuttl tests for the keystone operator, assumes that everything needed for running the test was deployed beforehand.
	KEYSTONE_KUTTL_DIR=${KEYSTONE_KUTTL_DIR} kubectl-kuttl test --config ${KEYSTONE_KUTTL_CONF} ${KEYSTONE_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: keystone_kuttl
keystone_kuttl: export NAMESPACE = ${KEYSTONE_KUTTL_NAMESPACE}
# Set the value of $KEYSTONE_KUTTL_NAMESPACE if you want to run the keystone
# kuttl tests in a namespace different than the default (keystone-kuttl-tests)
keystone_kuttl: namespace input openstack_crds deploy_cleanup mariadb mariadb_deploy mariadb_deploy_validate keystone_deploy_prep keystone ## runs kuttl tests for the keystone operator. Installs openstack crds and keystone operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make keystone_kuttl_run
	make deploy_cleanup
	make keystone_cleanup
	make mariadb_cleanup
	bash scripts/restore-namespace.sh

.PHONY: cinder_kuttl_run
cinder_kuttl_run: ## runs kuttl tests for the cinder operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${CINDER_KUTTL_CONF} ${CINDER_KUTTL_DIR}

.PHONY: cinder_kuttl
cinder_kuttl: namespace input openstack_crds openstack_storage_crds deploy_cleanup mariadb mariadb_deploy rabbitmq rabbitmq_deploy keystone_deploy_prep keystone keystone_deploy cinder_deploy_prep cinder infra mariadb_deploy_validate ## runs kuttl tests for the cinder operator. Installs openstack crds and cinder operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make cinder_kuttl_run
	make infra_cleanup
	make rabbitmq_deploy_cleanup
	make rabbitmq_cleanup
	make deploy_cleanup
	make cinder_cleanup
	make keystone_cleanup
	make mariadb_cleanup

.PHONY: neutron_kuttl_run
neutron_kuttl_run: ## runs kuttl tests for the neutron operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${NEUTRON_KUTTL_CONF} ${NEUTRON_KUTTL_DIR}

.PHONY: neutron_kuttl
neutron_kuttl: namespace input openstack_crds deploy_cleanup mariadb neutron_deploy_prep neutron mariadb_deploy keystone rabbitmq keystone_deploy ovn rabbitmq_deploy infra ovn_deploy   mariadb_deploy_validate ## runs kuttl tests for the neutron operator. Installs openstack crds and mariadb, keystone, rabbitmq, ovn, infra and neutron operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make neutron_kuttl_run
	make rabbitmq_deploy_cleanup
	make ovn_deploy_cleanup
	make deploy_cleanup
	make neutron_cleanup
	make ovn_cleanup
	make infra_cleanup
	make rabbitmq_cleanup
	make keystone_cleanup
	make mariadb_cleanup

.PHONY: octavia_kuttl_run
octavia_kuttl_run: ## runs kuttl tests for the octavia operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${OCTAVIA_KUTTL_CONF} ${OCTAVIA_KUTTL_DIR}

.PHONY: octavia_kuttl
octavia_kuttl: namespace input openstack_crds deploy_cleanup mariadb mariadb_deploy keystone ovn octavia_deploy_prep octavia ovn_deploy keystone_deploy mariadb_deploy_validate ## runs kuttl tests for the octavia operator. Installs openstack crds and mariadb, keystone, octavia, ovn operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make octavia_kuttl_run
	make ovn_deploy_cleanup
	make deploy_cleanup
	make octavia_cleanup
	make ovn_cleanup
	make keystone_cleanup
	make mariadb_cleanup

.PHONY: ovn_kuttl_run
ovn_kuttl_run: ## runs kuttl tests for the ovn operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${OVN_KUTTL_CONF} ${OVN_KUTTL_DIR}

.PHONY: ovn_kuttl
ovn_kuttl: namespace input openstack_crds deploy_cleanup ovn_deploy_prep ovn ## runs kuttl tests for the ovn operator. Installs openstack crds and ovn operator and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make ovn_kuttl_run
	make deploy_cleanup
	make ovn_cleanup

.PHONY: ovs_kuttl_run
ovs_kuttl_run: ## runs kuttl tests for the ovs operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${OVS_KUTTL_CONF} ${OVS_KUTTL_DIR}

.PHONY: ovs_kuttl
ovs_kuttl: namespace input openstack_crds deploy_cleanup ovn ovn_deploy ovs_deploy_prep ovs ## runs kuttl tests for the ovs operator. Installs openstack crds and ovn and ovs operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make ovs_kuttl_run
	make deploy_cleanup
	make ovn_cleanup
	make ovs_cleanup

.PHONY: ironic_kuttl_run
ironic_kuttl_run: ## runs kuttl tests for the ironic operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${IRONIC_KUTTL_CONF} ${IRONIC_KUTTL_DIR}

.PHONY: ironic_kuttl
ironic_kuttl: namespace input openstack_crds deploy_cleanup mariadb mariadb_deploy keystone keystone_deploy ironic ironic_deploy_prep ironic_deploy  ## runs kuttl tests for the ironic operator. Installs openstack crds and keystone operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make ironic_kuttl_run
	make deploy_cleanup
	make ironic_cleanup
	make keystone_cleanup
	make mariadb_cleanup

.PHONY: ironic_kuttl_crc
ironic_kuttl_crc: crc_storage ironic_kuttl

.PHONY: heat_kuttl_run
heat_kuttl_run: ## runs kuttl tests for the heat operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${HEAT_KUTTL_CONF} ${HEAT_KUTTL_DIR}

.PHONY: heat_kuttl
heat_kuttl: namespace input openstack_crds deploy_cleanup mariadb mariadb_deploy keystone keystone_deploy rabbitmq rabbitmq_deploy infra heat heat_deploy_prep  ## runs kuttl tests for the heat operator. Installs openstack crds and keystone operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make heat_kuttl_run
	make deploy_cleanup
	make rabbitmq_deploy_cleanup
	make infra_cleanup
	make rabbitmq_cleanup
	make heat_cleanup
	make keystone_cleanup
	make mariadb_cleanup

.PHONY: heat_kuttl_crc
heat_kuttl_crc: crc_storage heat_kuttl

.PHONY: ansibleee_kuttl_run
ansibleee_kuttl_run: ## runs kuttl tests for the openstack-ansibleee operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${ANSIBLEEE_KUTTL_CONF} ${ANSIBLEEE_KUTTL_DIR}

.PHONY: ansibleee_kuttl_cleanup
ansibleee_kuttl_cleanup:
	$(eval $(call vars,$@,openstack-ansibleee))
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/openstack-ansibleee-operator

.PHONY: ansibleee_kuttl_prep
ansibleee_kuttl_prep: ansibleee_kuttl_cleanup
	$(eval $(call vars,$@,openstack-ansibleee))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(ANSIBLEEE_BRANCH),-b ${ANSIBLEEE_BRANCH}) ${ANSIBLEEE_REPO} "${OPERATOR_NAME}-operator" && popd

.PHONY: ansibleee_kuttl
ansibleee_kuttl: namespace input openstack_crds ansibleee_kuttl_prep ansibleee ## runs kuttl tests for the openstack-ansibleee operator. Installs openstack crds and openstack-ansibleee operator and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make ansibleee_kuttl_run
	make ansibleee_cleanup

.PHONY: dataplane_kuttl_run
dataplane_kuttl_run: ## runs kuttl tests for the openstack-dataplane operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${DATAPLANE_KUTTL_CONF} ${DATAPLANE_KUTTL_DIR}

.PHONY: dataplane_kuttl_cleanup
dataplane_kuttl_cleanup:
	$(eval $(call vars,$@,openstack-dataplane))
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/dataplane-operator

.PHONY: dataplane_kuttl_prep
dataplane_kuttl_prep: dataplane_kuttl_cleanup
	$(eval $(call vars,$@,dataplane))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(DATAPLANE_BRANCH),-b ${DATAPLANE_BRANCH}) ${DATAPLANE_REPO} "${OPERATOR_NAME}-operator" && popd

.PHONY: dataplane_kuttl
dataplane_kuttl: namespace input openstack_crds dataplane_kuttl_prep dataplane ## runs kuttl tests for the openstack-dataplane operator. Installs openstack crds and openstack-dataplane operator and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make dataplane_kuttl_run
	make dataplane_cleanup

.PHONY: glance_kuttl_run
glance_kuttl_run: ## runs kuttl tests for the glance operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${GLANCE_KUTTL_CONF} ${GLANCE_KUTTL_DIR}

.PHONY: glance_kuttl
glance_kuttl: namespace input openstack_crds openstack_storage_crds deploy_cleanup mariadb mariadb_deploy keystone keystone_deploy glance_deploy_prep glance ## runs kuttl tests for the glance operator. Installs openstack and openstack-storage crds, mariadb, keystone and glance operators and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	make glance_kuttl_run
	make deploy_cleanup
	make cleanup

##@ HORIZON
.PHONY: horizon_prep
horizon_prep: export IMAGE=${HORIZON_IMG}
horizon_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,horizon))
	bash scripts/gen-olm.sh

.PHONY: horizon
horizon: namespace horizon_prep ## installs the operator, also runs the prep step. Set HORIZON_IMG for custom image.
	$(eval $(call vars,$@,horizon))
	oc apply -f ${OPERATOR_DIR}

.PHONY: horizon_cleanup
horizon_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,horizon))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: horizon_deploy_prep
horizon_deploy_prep: export KIND=Horizon
horizon_deploy_prep: export IMAGE=${HORIZON_DEPL_IMG}
horizon_deploy_prep: horizon_deploy_cleanup ## prepares the CR to install the service based on the service sample file HORIZON
	$(eval $(call vars,$@,horizon))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(HORIZON_BRANCH),-b ${HORIZON_BRANCH}) ${HORIZON_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${HORIZON_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: horizon_deploy
horizon_deploy: input horizon_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set HORIZON_REPO and HORIZON_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,horizon))
	bash scripts/operator-deploy-resources.sh

.PHONY: horizon_deploy_cleanup
horizon_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,horizon))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/horizon-operator ${DEPLOY_DIR}

##@ HEAT
.PHONY: heat_prep
heat_prep: export IMAGE=${HEAT_IMG}
heat_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,heat))
	bash scripts/gen-olm.sh

.PHONY: heat
heat: namespace heat_prep ## installs the operator, also runs the prep step. Set HEAT_IMG for custom image.
	$(eval $(call vars,$@,heat))
	oc apply -f ${OPERATOR_DIR}

.PHONY: heat_cleanup
heat_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,heat))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: heat_deploy_prep
heat_deploy_prep: export KIND=Heat
heat_deploy_prep: export IMAGE=${HEATAPI_DEPL_IMG},${HEATENGINE_DEPL_IMG}
heat_deploy_prep: export IMAGE_PATH=heatAPI/containerImage,heatEngine/containerImage
heat_deploy_prep: heat_deploy_cleanup ## prepares the CR to install the service based on the service sample file HEAT
	$(eval $(call vars,$@,heat))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(HEAT_BRANCH),-b ${HEAT_BRANCH}) ${HEAT_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${HEAT_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: heat_deploy
heat_deploy: input heat_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set HEAT_REPO and HEAT_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,heat))
	bash scripts/operator-deploy-resources.sh

.PHONY: heat_deploy_cleanup
heat_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,heat))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/heat-operator ${DEPLOY_DIR}

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
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

##@ BAREMETAL
.PHONY: baremetal_prep
baremetal_prep: export IMAGE=${BAREMETAL_IMG}
baremetal_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,openstack-baremetal))
	bash scripts/gen-olm.sh

.PHONY: baremetal
baremetal: namespace baremetal_prep ## installs the operator, also runs the prep step. Set BAREMETAL_IMG for custom image.
	$(eval $(call vars,$@,openstack-baremetal))
	oc apply -f ${OPERATOR_DIR}

.PHONY: baremetal_cleanup
baremetal_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,openstack-baremetal))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

##@ DATAPLANE
.PHONY: dataplane_prep
dataplane_prep: export IMAGE=${DATAPLANE_IMG}
dataplane_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,dataplane))
	bash scripts/gen-olm.sh

.PHONY: dataplane
dataplane: namespace dataplane_prep ## installs the operator, also runs the prep step. Set DATAPLANE_IMG for custom image.
	$(eval $(call vars,$@,dataplane))
	oc apply -f ${OPERATOR_DIR}

.PHONY: dataplane_cleanup
dataplane_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,dataplane))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

##@ CEPH
.PHONY: ceph_help
ceph_help: export IMAGE=${CEPH_IMG}
ceph_help: ## Ceph helper
	$(eval $(call vars,$@,ceph))
	bash scripts/gen-ceph-kustomize.sh "help" "full"

.PHONY: ceph
ceph: export IMAGE=${CEPH_IMG}
ceph: namespace ## deploy the Ceph Pod
	$(eval $(call vars,$@,ceph))
	bash scripts/gen-ceph-kustomize.sh "build"
	bash scripts/operator-deploy-resources.sh
	bash scripts/gen-ceph-kustomize.sh "isready"
	bash scripts/gen-ceph-kustomize.sh "cephfs"
	bash scripts/gen-ceph-kustomize.sh "pools"
	bash scripts/gen-ceph-kustomize.sh "secret"

.PHONY: ceph_cleanup
ceph_cleanup: ## deletes the ceph pod
	$(eval $(call vars,$@,ceph))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${DEPLOY_DIR}

##@ NMSTATE
.PHONY: nmstate
nmstate: export NAMESPACE=openshift-nmstate
nmstate: ## installs nmstate operator in the openshift-nmstate namespace
	$(eval $(call vars,$@,nmstate))
	bash scripts/gen-namespace.sh
	oc apply -f ${OUT}/${NAMESPACE}/namespace.yaml
	sleep 2
	bash scripts/gen-olm-nmstate.sh
	oc apply -f ${OPERATOR_DIR}
	while ! (oc get pod --no-headers=true -l app=kubernetes-nmstate-operator -n ${NAMESPACE}| grep "nmstate-operator"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} --for condition=Ready -l app=kubernetes-nmstate-operator --timeout=300s
	oc apply -f ${DEPLOY_DIR}
	while ! (oc get pod --no-headers=true -l component=kubernetes-nmstate-handler -n ${NAMESPACE}| grep "nmstate-handler"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} -l component=kubernetes-nmstate-handler --for condition=Ready --timeout=300s
	while ! (oc get pod --no-headers=true -l component=kubernetes-nmstate-webhook -n ${NAMESPACE}| grep "nmstate-webhook"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} -l component=kubernetes-nmstate-webhook --for condition=Ready --timeout=300s

.PHONY: nncp
nncp: export INTERFACE=${NNCP_INTERFACE}
nncp: ## installs the nncp resources to configure the interface connected to the edpm node, right now only single nic vlan. Interface referenced via NNCP_INTERFACE
	$(eval $(call vars,$@,nncp))
	WORKERS='$(shell oc get nodes -l node-role.kubernetes.io/worker -o jsonpath="{.items[*].metadata.name}")' \
	bash scripts/gen-nncp.sh
	oc apply -f ${DEPLOY_DIR}/
	oc wait nncp -l osp/interface=${NNCP_INTERFACE} --for condition=available --timeout=240s

.PHONY: nncp_cleanup
nncp_cleanup: export INTERFACE=${NNCP_INTERFACE}
nncp_cleanup: ## unconfigured nncp configuration on worker node and deletes the nncp resource
	$(eval $(call vars,$@,nncp))
	sed -i 's/state: up/state: absent/' ${DEPLOY_DIR}/*_nncp.yaml
	oc apply -f ${DEPLOY_DIR}/
	oc wait nncp -l osp/interface=${NNCP_INTERFACE} --for condition=available --timeout=120s
	oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/
	${CLEANUP_DIR_CMD} ${DEPLOY_DIR}

.PHONY: netattach
netattach: export INTERFACE=${NNCP_INTERFACE}
netattach: namespace ## Creates network-attachment-definitions for the networks the workers are attached via nncp
	$(eval $(call vars,$@,netattach))
	bash scripts/gen-netatt.sh
	oc apply -f ${DEPLOY_DIR}/

.PHONY: netattach_cleanup
netattach_cleanup: ## Deletes the network-attachment-definitions
	$(eval $(call vars,$@,netattach))
	oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/
	${CLEANUP_DIR_CMD} ${DEPLOY_DIR}

##@ METALLB
.PHONY: metallb
metallb: export NAMESPACE=metallb-system
metallb: export INTERFACE=${NNCP_INTERFACE}
metallb: ## installs metallb operator in the metallb-system namespace
	$(eval $(call vars,$@,metallb))
	bash scripts/gen-namespace.sh
	oc apply -f ${OUT}/${NAMESPACE}/namespace.yaml
	sleep 2
	bash scripts/gen-olm-metallb.sh
	oc apply -f ${OPERATOR_DIR}
	while ! (oc get pod --no-headers=true -l control-plane=controller-manager -n ${NAMESPACE}| grep "metallb-operator-controller"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} --for condition=Ready -l control-plane=controller-manager --timeout=300s
	while ! (oc get pod --no-headers=true -l component=webhook-server -n ${NAMESPACE}| grep "metallb-operator-webhook"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} --for condition=Ready -l component=webhook-server --timeout=300s
	oc apply -f ${DEPLOY_DIR}/deploy_operator.yaml
	while ! (oc get pod --no-headers=true -l component=speaker -n ${NAMESPACE} | grep "speaker"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} -l component=speaker --for condition=Ready --timeout=300s

.PHONY: metallb_config
metallb_config: export NAMESPACE=metallb-system
metallb_config: export INTERFACE=${NNCP_INTERFACE}
metallb_config: ## creates the IPAddressPools and l2advertisement resources
	$(eval $(call vars,$@,metallb))
	bash scripts/gen-olm-metallb.sh
	oc apply -f ${DEPLOY_DIR}/ipaddresspools.yaml
	oc apply -f ${DEPLOY_DIR}/l2advertisement.yaml

.PHONY: metallb_config_cleanup
metallb_config_cleanup: export NAMESPACE=metallb-system
metallb_config_cleanup: ## deletes the IPAddressPools and l2advertisement resources
	$(eval $(call vars,$@,metallb))
	oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/ipaddresspools.yaml
	oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/l2advertisement.yaml
	${CLEANUP_DIR_CMD} ${DEPLOY_DIR}/ipaddresspools.yaml ${DEPLOY_DIR}/l2advertisement.yaml

##@ MANILA
.PHONY: manila_prep
manila_prep: export IMAGE=${MANILA_IMG}
manila_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,manila))
	bash scripts/gen-olm.sh

.PHONY: manila
manila: namespace manila_prep ## installs the operator, also runs the prep step. Set MANILA_IMG for custom image.
	$(eval $(call vars,$@,manila))
	oc apply -f ${OPERATOR_DIR}

.PHONY: manila_cleanup
manila_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,manila))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: manila_deploy_prep
manila_deploy_prep: export KIND=Manila
manila_deploy_prep: manila_deploy_cleanup ## prepares the CR to install the service based on the service sample file MANILA
	$(eval $(call vars,$@,manila))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(MANILA_BRANCH),-b ${MANILA_BRANCH}) ${MANILA_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${MANILA_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: manila_deploy
manila_deploy: input manila_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set CINDER_REPO and CINDER_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,manila))
	# bash scripts/operator-deploy-resources.sh

.PHONY: manila_deploy_cleanup
manila_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,manila))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/manila-operator ${DEPLOY_DIR}
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database manila;" || true

##@ TELEMETRY
.PHONY: telemetry_prep
telemetry_prep: export IMAGE=${TELEMETRY_IMG}
telemetry_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,telemetry))
	bash scripts/gen-olm.sh

.PHONY: telemetry
telemetry: namespace telemetry_prep ## installs the operator, also runs the prep step. Set TELEMETRY_IMG for custom image.
	$(eval $(call vars,$@,telemetry))
	oc apply -f ${OPERATOR_DIR}

.PHONY: telemetry_cleanup
telemetry_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,telemetry))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: telemetry_deploy_prep
telemetry_deploy_prep: export KIND=Telemetry
telemetry_deploy_prep: export IMAGE=${CEILOMETER_CENTRAL_DEPL_IMG},${CEILOMETER_NOTIFICATION_DEPL_IMG},${SG_CORE_DEPL_IMG}
telemetry_deploy_prep: export IMAGE_PATH=centralImage,notificationImage,sgCoreImage
telemetry_deploy_prep: telemetry_deploy_cleanup ## prepares the CR to install the service based on the service sample file TELEMETRY
	$(eval $(call vars,$@,telemetry))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone ${GIT_CLONE_OPTS} $(if $(TELEMETRY_BRANCH),-b ${TELEMETRY_BRANCH}) ${TELEMETRY_REPO} "${OPERATOR_NAME}-operator" && popd
	cp ${TELEMETRY_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: telemetry_deploy
telemetry_deploy: input telemetry_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set TELEMETRY_REPO and TELEMETRY_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,telemetry))
	bash scripts/operator-deploy-resources.sh

.PHONY: telemetry_deploy_cleanup
telemetry_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,telemetry))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/telemetry-operator ${DEPLOY_DIR}
	rm -Rf ${OPERATOR_BASE_DIR}/ceilometer-operator ${DEPLOY_DIR}


##@ SWIFT
.PHONY: swift_prep
swift_prep: export IMAGE=${SWIFT_IMG}
swift_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,swift))
	bash scripts/gen-olm.sh

.PHONY: swift
swift: namespace swift_prep ## installs the operator, also runs the prep step. Set SWIFT_IMG for custom image.
	$(eval $(call vars,$@,swift))
	oc apply -f ${OPERATOR_DIR}

.PHONY: swift_cleanup
swift_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,swift))
	bash scripts/operator-cleanup.sh
	rm -Rf ${OPERATOR_DIR}

.PHONY: swift_deploy_prep
swift_deploy_prep: export KIND=SwiftRing
swift_deploy_prep: export IMAGE=unused
swift_deploy_prep: swift_deploy_cleanup ## prepares the CR to install the service based on the service sample file SWIFTAPI
	$(eval $(call vars,$@,swift))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${SWIFT_BRANCH} ${SWIFT_REPO} && popd
	cp ${SWIFTRING_CR} ${DEPLOY_DIR}
	cp ${SWIFTSTORAGE_CR} ${DEPLOY_DIR}
	cp ${SWIFTPROXY_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: swift_deploy
swift_deploy: input swift_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set SWIFT_REPO and SWIFT_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,swift))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: swift_deploy_cleanup
swift_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,swift))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	rm -Rf ${OPERATOR_BASE_DIR}/swift-operator ${DEPLOY_DIR}
