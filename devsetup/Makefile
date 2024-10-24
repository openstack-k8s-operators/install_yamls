CRC_VERSION ?= latest
CRC_URL ?= 'https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/$(CRC_VERSION)/crc-linux-amd64.tar.xz'
KUBEADMIN_PWD ?= 12345678
PULL_SECRET  ?= ${PWD}/pull-secret.txt
TIMEOUT                  ?= 300s
DOWNLOAD_TOOLS_SELECTION ?= all

CRC_HTTP_PROXY ?=
CRC_HTTPS_PROXY ?=

OCP_NETWORK_NAME ?=crc
NETWORK_ISOLATION_USE_DEFAULT_NETWORK ?= true

NETWORK_ISOLATION_MAC ?= 52:54:00:11:11:10
ifeq ($(NETWORK_ISOLATION_USE_DEFAULT_NETWORK), true)
NETWORK_ISOLATION_NET_NAME ?= default
NETWORK_ISOLATION_IP_ADDRESS ?= 192.168.122.10
else
NETWORK_ISOLATION_NET_NAME ?= net-iso
NETWORK_ISOLATION_IP_ADDRESS ?= 172.16.1.10
endif
NETWORK_ISOLATION_NETWORK_NAME ?= net-iso
NETWORK_ISOLATION_IPV4 ?= true
NETWORK_ISOLATION_IPV6 ?= false
NETWORK_ISOLATION_IPV4_ADDRESS ?= 172.16.1.1/24
NETWORK_ISOLATION_IPV4_NAT ?= true
NETWORK_ISOLATION_IPV6_ADDRESS ?= fd00:aaaa::1/64
NETWORK_ISOLATION_INSTANCE_NAME ?= crc

EDPM_COMPUTE_SUFFIX ?= 0
EDPM_NETWORKER_SUFFIX ?= 0
# EDPM_COMPUTE_ADDITIONAL_NETWORKS: JSON string - list of additional networks
# Examples:
#   cat > additional_nets.json << EOF
#   [
#     {
#       "type": "network",
#       "name": "crc-bmaas",
#       "standalone_config": {
#         "type": "linux_bridge",
#         "name": "baremetal",
#         "mtu": 1500,
#         "ip_subnet": "172.20.1.0/24",
#         "allocation_pools": [
#           {
#             "start": "172.20.1.4",
#             "end": "172.20.1.250"
#           }
#         ]
#       }
#     }
#   ]
#   EOF
#   EDPM_COMPUTE_ADDITIONAL_NETWORKS=$(cat additional_nets.json | jq -c)
EDPM_COMPUTE_ADDITIONAL_NETWORKS ?= '[]'

# EDPM_COMPUTE_ADDITIONAL_HOST_ROUTES="[172.31.0.0/24,172.32.0.0/24]"
EDPM_COMPUTE_ADDITIONAL_HOST_ROUTES ?= '[]'

EDPM_FIRSTBOOT_EXTRA ?= /tmp/edpm-firstboot-extra

TLS_ENABLED ?= false
DNS_DOMAIN ?= localdomain

BARBICAN_SERVICE_ENABLED ?= true
MANILA_SERVICE_ENABLED ?= true

EDPM_TOTAL_NODES ?= 1
RH_REGISTRY_USER ?= ""
RH_REGISTRY_PWD ?= ""
EDPM_CONFIGURE_HUGEPAGES ?= false
EDPM_COMPUTE_CEPH_ENABLED ?= true
EDPM_COMPUTE_CELLS ?= 1
EDPM_COMPUTE_CEPH_NOVA ?= true
EDPM_CONFIGURE_NETWORKING ?= true
EDPM_COMPUTE_SRIOV_ENABLED ?= true
EDPM_COMPUTE_DHCP_AGENT_ENABLED ?= true
EDPM_TOTAL_NETWORKERS ?= 1
NETWORK_MTU	?= 1500

NETWORK_BGP ?= false
CRC_BGP_NIC_1_MAC ?= 52:54:00:11:11:11
CRC_BGP_NIC_2_MAC ?= 52:54:00:11:11:12

BMAAS_OCP_INSTANCE_NAME ?= crc
BMAAS_INSTANCE_NAME_PREFIX ?= crc-bmaas
BMAAS_INSTANCE_MEMORY ?= 4096
BMAAS_INSTANCE_VCPUS ?= 2
BMAAS_INSTANCE_DISK_SIZE ?= 20
BMAAS_INSTANCE_OS_VARIANT ?= centos-stream9
BMAAS_INSTANCE_VIRT_TYPE ?= kvm
BMAAS_INSTANCE_NET_MODEL ?= virtio
BMAAS_NETWORK_NAME ?= crc-bmaas
BMAAS_IPV4 ?= true
BMAAS_IPV6 ?= false
BMAAS_NETWORK_IPV4_PREFIX ?= 172.20.1.1/24
BMAAS_BRIDGE_IPV4_PREFIX ?= 172.20.1.2/24
BMAAS_METALLB_POOL_NAME ?= baremetal
BMAAS_METALLB_ADDRESS_POOL ?= 172.20.1.64/26
BMAAS_NETWORK_IPV6_PREFIX ?= fd00:bbbb::1/64
BMAAS_BRIDGE_IPV6_PREFIX ?= fd00:bbbb::2/64
BMAAS_NODE_COUNT ?= 1
BMAAS_REDFISH_USERNAME ?= admin
BMAAS_REDFISH_PASSWORD ?= password
BMAAS_SUSHY_EMULATOR_NAMESPACE ?= sushy-emulator
BMAAS_SUSHY_EMULATOR_DRIVER ?= libvirt
BMAAS_SUSHY_EMULATOR_IMAGE ?= quay.io/metal3-io/sushy-tools:latest
BMAAS_SUSHY_EMULATOR_OS_CLOUD ?= openstack
BMAAS_SUSHY_EMULATOR_OS_CLIENT_CONFIG_FILE ?= /etc/openstack/clouds.yaml
BMAAS_LIBVIRT_USER ?= sushyemu
BMAAS_ROUTE_LIBVIRT_NETWORKS ?= ${BMAAS_NETWORK_NAME},crc,default

DATAPLANE_PLAYBOOK ?= osp.edpm.download_cache
DATAPLANE_CUSTOM_SERVICE_RUNNER_IMG ?=quay.io/openstack-k8s-operators/openstack-ansibleee-runner:latest
BM_NETWORK_NAME            ?=default
BM_INSTANCE_NAME_PREFIX    ?=edpm-compute
BM_NODE_COUNT              ?=1
BM_ROOT_PASSWORD_SECRET    ?=
BMH_NAMESPACE              ?=openstack

IPV6_LAB_WORK_DIR                 ?= ${HOME}/.ipv6lab
IPV6_LAB_SSH_PUB_KEY              ?= ${HOME}/.ssh/id_rsa.pub
IPV6_LAB_LIBVIRT_STORAGE_POOL     ?= default
IPV6_LAB_NETWORK_NAME             ?= nat64
IPV6_LAB_MANAGE_FIREWALLD         ?= true
IPV6_LAB_IPV6_NETWORK_IPADDRESS   ?= fd00:abcd:abcd:fc00::1/64
IPV6_LAB_IPV4_NETWORK_IPADDRESS   ?= 172.30.0.1/24
IPV6_LAB_NAT64_INSTANCE_NAME      ?= nat64-router
IPV6_LAB_NAT64_HOST_IPV6          ?= fd00:abcd:abcd:fc00::2/64
IPV6_LAB_NAT64_HOST_IPV4          ?= 172.30.0.2/24
IPV6_LAB_NAT64_TAYGA_IPV4         ?= 192.168.255.1
IPV6_LAB_NAT64_TAYGA_IPV6         ?= fd00:abcd:abcd:fc00::3
IPV6_LAB_NAT64_TAYGA_DYNAMIC_POOL ?= 192.168.255.0/24
IPV6_LAB_NAT64_TAYGA_IPV6_PREFIX  ?= fd00:abcd:abcd:fcff::/96
IPV6_LAB_NAT64_IPV6_NETWORK       ?= fd00:abcd:abcd:fc00::/64
IPV6_LAB_NAT64_UPDATE_PACKAGES    ?= false
IPV6_LAB_SNO_INSTANCE_NAME        ?= sno
IPV6_LAB_SNO_CLUSTER_NETWORK      ?= fd00:abcd:0::/48
IPV6_LAB_SNO_HOST_PREFIX          ?= 64
IPV6_LAB_SNO_MACHINE_NETWORK      ?= fd00:abcd:abcd:fc00::/64
IPV6_LAB_SNO_SERVICE_NETWORK      ?= fd00:abcd:abcd:fc03::/112
IPV6_LAB_SNO_HOST_IP              ?= fd00:abcd:abcd:fc00::11
IPV6_LAB_SNO_OCP_VERSION          ?= latest-4.14
IPV6_LAB_SNO_OCP_MIRROR_URL       ?= https://mirror.openshift.com/pub/openshift-v4/clients/ocp

# default number of instances to deploy via edpm_deploy_instance
NUMBER_OF_INSTANCES    ?=1

# base directory used for the nfs server
NFS_HOME	?= /home/nfs

STANDALONE_COMPUTE_DRIVER ?= libvirt

CLEANUP_DIR_CMD ?= rm -Rf

define vars
${1}: export CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD}
${1}: export NFS_HOME=${NFS_HOME}
endef

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

##@ Download required tools and versions
.PHONY: download_tools
download_tools: ## Runs an ansible playbook to install required tools with the versions to develop the service operators. The tools get installed in ~/bin and go in /usr/local/go (alternatives get used to set it as the system wide go version). You can select installed tools using DOWNLOAD_TOOLS_SELECTION listing the wanted tags (dependencies, golang, kubectl, kustomize, kuttl, operator_sdk, opm, yq).
	ANSIBLE_FORCE_COLOR=true ansible-playbook \
	-v -i hosts --tags ${DOWNLOAD_TOOLS_SELECTION} \
	download_tools.yaml

##@ Configure nfs server on the host
.PHONY: nfs
nfs: ## Runs an ansible playbook to install nfs rpms, uses per default /home/nfs as the data dir and exports shared for OSP services.
	$(eval $(call vars))
	ANSIBLE_FORCE_COLOR=true ansible-playbook \
	-v -i hosts nfs.yaml

.PHONY: nfs_cleanup
nfs_cleanup: ## removes /etc/exports.d/osp.exports, reloads nfs exports and deletes /home/nfs
	$(eval $(call vars))
	sudo rm -f /etc/exports.d/osp.exports
	sudo exportfs -ra
	sudo ${CLEANUP_DIR_CMD} ${NFS_HOME}

##@ CRC
.PHONY: crc
crc: ## Deploys CRC using CRC_URL to download and install CRC, KUBEADMIN_PWD as the password which defaults to 12345678 and PULL_SECRET to specify the file containing the pull secret, defaults to ${PWD}/pull-secret.txt. To change the default memory and/or cpus for the VM use `CPUS=X MEMORY=Y DISK=Z make crc`.
	bash scripts/crc-setup.sh ${CRC_URL} ${KUBEADMIN_PWD} ${PULL_SECRET}

.PHONY: crc_cleanup
crc_cleanup: ## Destroys the CRC env, but does NOT clear ( --clear-cache ) the cache to save time on next setup.
	crc delete --force
	crc cleanup
	sudo ${CLEANUP_DIR_CMD} /etc/pki/ca-trust/source/anchors/crc-router-ca.pem
	sudo update-ca-trust

.PHONY: crc_scrub
crc_scrub:
	make crc_cleanup || true
	rm -rf ~/.crc
	sudo rm $$(which crc)

.PHONY: crc_attach_default_interface
crc_attach_default_interface:
	make attach_default_interface

.PHONY: crc_attach_default_interface_cleanup
crc_attach_default_interface_cleanup:
	make attach_default_interface_cleanup

##@ IPv6 Lab
.PHONY: ipv6_lab_network
ipv6_lab_network: export WORK_DIR = ${IPV6_LAB_WORK_DIR}
ipv6_lab_network: export NETWORK_NAME = ${IPV6_LAB_NETWORK_NAME}
ipv6_lab_network: export MANAGE_FIREWALLD = ${IPV6_LAB_MANAGE_FIREWALLD}
ipv6_lab_network: export IPV6_NETWORK_IPADDRESS = ${IPV6_LAB_IPV6_NETWORK_IPADDRESS}
ipv6_lab_network: export IPV4_NETWORK_IPADDRESS = ${IPV6_LAB_IPV4_NETWORK_IPADDRESS}
ipv6_lab_network: export NAT64_HOST_IPV6 = ${IPV6_LAB_NAT64_HOST_IPV6}
ipv6_lab_network: ## Deploys libvirt network for IPv6 lab
	bash scripts/ipv6-nat64/network.sh --create

.PHONY: ipv6_lab_network_cleanup
ipv6_lab_network_cleanup: export WORK_DIR = ${IPV6_LAB_WORK_DIR}
ipv6_lab_network_cleanup: export NETWORK_NAME = ${IPV6_LAB_NETWORK_NAME}
ipv6_lab_network_cleanup: export MANAGE_FIREWALLD = ${IPV6_LAB_MANAGE_FIREWALLD}
ipv6_lab_network_cleanup: ## Deploys libvirt network for IPv6 lab
	bash scripts/ipv6-nat64/network.sh --cleanup

.PHONY: ipv6_lab_nat64_router
ipv6_lab_nat64_router: export WORK_DIR = ${IPV6_LAB_WORK_DIR}
ipv6_lab_nat64_router: export NETWORK_NAME = ${IPV6_LAB_NETWORK_NAME}
ipv6_lab_nat64_router: export IPV6_NETWORK_IPADDRESS = ${IPV6_LAB_IPV6_NETWORK_IPADDRESS}
ipv6_lab_nat64_router: export IPV4_NETWORK_IPADDRESS = ${IPV6_LAB_IPV4_NETWORK_IPADDRESS}
ipv6_lab_nat64_router: export NAT64_HOST_IPV6 = ${IPV6_LAB_NAT64_HOST_IPV6}
ipv6_lab_nat64_router: export NAT64_TAYGA_IPV4 = ${IPV6_LAB_NAT64_TAYGA_IPV4}
ipv6_lab_nat64_router: export NAT64_TAYGA_IPV6 = ${IPV6_LAB_NAT64_TAYGA_IPV6}
ipv6_lab_nat64_router: export NAT64_TAYGA_DYNAMIC_POOL = ${IPV6_LAB_NAT64_TAYGA_DYNAMIC_POOL}
ipv6_lab_nat64_router: export NAT64_TAYGA_IPV6_PREFIX = ${IPV6_LAB_NAT64_TAYGA_IPV6_PREFIX}
ipv6_lab_nat64_router: export NAT64_INSTANCE_NAME = ${IPV6_LAB_NAT64_INSTANCE_NAME}
ipv6_lab_nat64_router: export SSH_PUB_KEY = ${IPV6_LAB_SSH_PUB_KEY}
ipv6_lab_nat64_router: export LIBVIRT_STORAGE_POOL = ${IPV6_LAB_LIBVIRT_STORAGE_POOL}
ipv6_lab_nat64_router: export UPDATE_PACKAGES = ${IPV6_LAB_NAT64_UPDATE_PACKAGES}
ipv6_lab_nat64_router: export NET_ISOLATION_IPV6_ADDR = ${NETWORK_ISOLATION_IPV6_ADDRESS}
ipv6_lab_nat64_router: ## Deploys NAT64/DNS64 router node
	bash scripts/ipv6-nat64/nat64_router.sh --create

.PHONY: ipv6_lab_nat64_router_cleanup
ipv6_lab_nat64_router_cleanup: export WORK_DIR = ${IPV6_LAB_WORK_DIR}
ipv6_lab_nat64_router_cleanup: export NAT64_INSTANCE_NAME = ${IPV6_LAB_NAT64_INSTANCE_NAME}
ipv6_lab_nat64_router_cleanup: ## Deploys NAT64/DNS64 router node
	bash scripts/ipv6-nat64/nat64_router.sh --cleanup

.PHONY: ipv6_lab_sno
ipv6_lab_sno: export WORK_DIR = ${IPV6_LAB_WORK_DIR}
ipv6_lab_sno: export SSH_PUB_KEY = ${IPV6_LAB_SSH_PUB_KEY}
ipv6_lab_sno: export OCP_VERSION = ${IPV6_LAB_SNO_OCP_VERSION}
ipv6_lab_sno: export OCP_MIRROR_URL = ${IPV6_LAB_SNO_OCP_MIRROR_URL}
ipv6_lab_sno: export OCP_ADMIN_PASSWD = ${KUBEADMIN_PWD}
ipv6_lab_sno: export NETWORK_NAME = ${IPV6_LAB_NETWORK_NAME}
ipv6_lab_sno: export SNO_CLUSTER_NETWORK = ${IPV6_LAB_SNO_CLUSTER_NETWORK}
ipv6_lab_sno: export SNO_HOST_PREFIX = ${IPV6_LAB_SNO_HOST_PREFIX}
ipv6_lab_sno: export SNO_MACHINE_NETWORK = ${IPV6_LAB_SNO_MACHINE_NETWORK}
ipv6_lab_sno: export SNO_SERVICE_NETWORK = ${IPV6_LAB_SNO_SERVICE_NETWORK}
ipv6_lab_sno: export SNO_HOST_IP = ${IPV6_LAB_SNO_HOST_IP}
ipv6_lab_sno: export SNO_INSTANCE_NAME = ${IPV6_LAB_SNO_INSTANCE_NAME}
ipv6_lab_sno: export LIBVIRT_STORAGE_POOL = ${IPV6_LAB_LIBVIRT_STORAGE_POOL}
ipv6_lab_sno: ## Deployes Single-node-Openshift
	bash scripts/ipv6-nat64/sno.sh --create

.PHONY: ipv6_lab_sno_cleanup
ipv6_lab_sno_cleanup: export WORK_DIR = ${IPV6_LAB_WORK_DIR}
ipv6_lab_sno_cleanup: export SNO_INSTANCE_NAME = ${IPV6_LAB_SNO_INSTANCE_NAME}
ipv6_lab_sno_cleanup: export NETWORK_NAME = ${IPV6_LAB_NETWORK_NAME}
ipv6_lab_sno_cleanup:  ## Destroys Single-node-Openshift
	bash scripts/ipv6-nat64/sno.sh --cleanup


.PHONY: ipv6_lab
ipv6_lab: ## Deploys IPv6 lab environment
	make ipv6_lab_network
	make ipv6_lab_nat64_router
	make ipv6_lab_sno

.PHONY: ipv6_lab_cleanup
ipv6_lab_cleanup: ## Deploys IPv6 lab environment
	make ipv6_lab_sno_cleanup
	make ipv6_lab_nat64_router_cleanup
	make ipv6_lab_network_cleanup

	# some files in the work directory can get obsolete after a short time
	# and break further deployment attempts
	rm -rf ${IPV6_LAB_WORK_DIR}

##@ Attach interface

.PHONY: attach_default_interface
ifeq ($(NETWORK_BGP), true)
attach_default_interface: export BGP=enabled
attach_default_interface: export BGP_NIC_1_MAC=${CRC_BGP_NIC_1_MAC}
attach_default_interface: export BGP_NIC_2_MAC=${CRC_BGP_NIC_2_MAC}
endif
attach_default_interface: export IP_ADDRESS=${NETWORK_ISOLATION_IP_ADDRESS}
attach_default_interface: export NETWORK_NAME=${NETWORK_ISOLATION_NET_NAME}
attach_default_interface: export INSTANCE_NAME=${NETWORK_ISOLATION_INSTANCE_NAME}
attach_default_interface: export MAC_ADDRESS=${NETWORK_ISOLATION_MAC}
attach_default_interface: attach_default_interface_cleanup ## Attach default libvirt network to CRC
	bash scripts/interfaces-setup.sh

.PHONY: attach_default_interface_cleanup
ifeq ($(NETWORK_BGP), true)
attach_default_interface_cleanup: export BGP=enabled
attach_default_interface_cleanup: export BGP_NIC_1_MAC=${CRC_BGP_NIC_1_MAC}
attach_default_interface_cleanup: export BGP_NIC_2_MAC=${CRC_BGP_NIC_2_MAC}
endif
attach_default_interface_cleanup: export INSTANCE_NAME=${NETWORK_ISOLATION_INSTANCE_NAME}
attach_default_interface_cleanup: export NETWORK_NAME=${NETWORK_ISOLATION_NET_NAME}
attach_default_interface_cleanup: ## Detach default libvirt network from CRC
	bash scripts/interfaces-setup-cleanup.sh

##@ Network-Isolation

.PHONY: network_isolation_bridge
network_isolation_bridge: export NETWORK_NAME=${NETWORK_ISOLATION_NETWORK_NAME}
ifeq ($(NETWORK_ISOLATION_IPV4), true)
network_isolation_bridge: export IPV4_ADDRESS=${NETWORK_ISOLATION_IPV4_ADDRESS}
network_isolation_bridge: export IPV4_NAT=${NETWORK_ISOLATION_IPV4_NAT}
endif
ifeq ($(NETWORK_ISOLATION_IPV6), true)
network_isolation_bridge: export IPV6_NAT64=true
network_isolation_bridge: export IPV6_ADDRESS=${NETWORK_ISOLATION_IPV6_ADDRESS}
network_isolation_bridge: export NAT64_HOST_IPV6=${IPV6_LAB_NAT64_HOST_IPV6}
network_isolation_bridge: export NAT64_TAYGA_IPV6_PREFIX=${IPV6_LAB_NAT64_TAYGA_IPV6_PREFIX}
endif
network_isolation_bridge: ## Create libvirt network isolation network
	scripts/network-setup.sh --create

.PHONY: network_isolation_bridge_cleanup
ifeq ($(NETWORK_ISOLATION_IPV6), true)
network_isolation_bridge: export IPV6_NAT64=true
network_isolation_bridge_cleanup: export NAT64_TAYGA_IPV6_PREFIX=${IPV6_LAB_NAT64_TAYGA_IPV6_PREFIX}
endif
network_isolation_bridge_cleanup: export NETWORK_NAME=${NETWORK_ISOLATION_NETWORK_NAME}
network_isolation_bridge_cleanup: ## Cleanup libvirt network isolation network
	scripts/network-setup.sh --cleanup

##@ EDPM

.PHONY: edpm_baremetal_compute
edpm_baremetal_compute: export OPERATOR_NAME=openstack
edpm_baremetal_compute: export NAMESPACE=${BMH_NAMESPACE}
edpm_baremetal_compute: export BMAAS_NETWORK_NAME=${BM_NETWORK_NAME}
edpm_baremetal_compute: export BMAAS_INSTANCE_NAME_PREFIX=${BM_INSTANCE_NAME_PREFIX}
edpm_baremetal_compute: export BMAAS_NODE_COUNT=${BM_NODE_COUNT}
edpm_baremetal_compute: export NODE_COUNT=${BM_NODE_COUNT}
edpm_baremetal_compute: export DEPLOY_DIR=../out/bmaas
edpm_baremetal_compute: ## Create virtual baremetal for the dataplane
	$(eval $(call vars))
	make bmaas_virtual_bms
	make bmaas_sushy_emulator_wait
	bash scripts/edpm-compute-baremetal.sh --create

edpm_baremetal_compute_cleanup: export BMAAS_NETWORK_NAME=${BM_NETWORK_NAME}
edpm_baremetal_compute_cleanup: export NAMESPACE=${BMH_NAMESPACE}
edpm_baremetal_compute_cleanup: export BMAAS_INSTANCE_NAME_PREFIX=${BM_INSTANCE_NAME_PREFIX}
edpm_baremetal_compute_cleanup: export BMAAS_NODE_COUNT=${BM_NODE_COUNT}
edpm_baremetal_compute_cleanup: export NODE_COUNT=${BM_NODE_COUNT}
edpm_baremetal_compute_cleanup:  ## Cleanup dataplane with BMAAS
	$(eval $(call vars))
	scripts/edpm-compute-baremetal.sh --cleanup
	pushd .. && rm -Rf out/edpm || true && popd
	make bmaas_sushy_emulator_cleanup || true
	make bmaas_virtual_bms_cleanup || true

.PHONY: edpm_compute
edpm_compute: export EDPM_COMPUTE_NETWORK = ${NETWORK_ISOLATION_NET_NAME}
edpm_compute: export FIRSTBOOT_EXTRA = ${EDPM_FIRSTBOOT_EXTRA}
edpm_compute: ## Create EDPM compute VM
	$(eval $(call vars))
	scripts/gen-ansibleee-ssh-key.sh
	if [ ${EDPM_TOTAL_NODES} -eq 1 ]; then \
		scripts/gen-edpm-node.sh ${EDPM_COMPUTE_SUFFIX} '${EDPM_COMPUTE_ADDITIONAL_NETWORKS}'; \
	else \
		for INDEX in $(shell seq 0 $$((${EDPM_TOTAL_NODES} -1))) ; do \
			scripts/gen-edpm-node.sh $$INDEX '${EDPM_COMPUTE_ADDITIONAL_NETWORKS}' ; \
		done \
	fi

.PHONY: edpm_ansible_runner
edpm_ansible_runner: export EDPM_PLAYBOOK=${DATAPLANE_PLAYBOOK}
edpm_ansible_runner: export OPENSTACK_RUNNER_IMG=${DATAPLANE_CUSTOM_SERVICE_RUNNER_IMG}
edpm_ansible_runner: ## Debug edpm-ansible playbooks
	$(eval $(call vars))
	scripts/edpm-ansible-runner.sh

.PHONY: edpm_computes_bgp
edpm_computes_bgp: #
	$(eval $(call vars))
	scripts/gen-ansibleee-ssh-key.sh
	scripts/gen-edpm-node-bgp.sh

.PHONY: edpm_compute_repos
edpm_compute_repos: ## Configure EDPM compute VM with repositories
	@echo "DEPRECATED: this target has no effect and will be removed. Repo setup is done by the 'repo-setup' ansible service"

.PHONY: edpm_compute_cleanup
edpm_compute_cleanup: ## Delete EDPM compute VM
	$(eval $(call vars))
	if [ ${EDPM_TOTAL_NODES} -eq 1 ]; then \
		scripts/edpm-node-cleanup.sh ${EDPM_COMPUTE_SUFFIX}; \
	else \
		for INDEX in $(shell seq 0 $$((${EDPM_TOTAL_NODES} -1))) ; do \
			scripts/edpm-node-cleanup.sh $$INDEX ; \
		done \
	fi

.PHONY: edpm_networker
edpm_networker: export EDPM_SERVER_ROLE=networker
edpm_networker: ## Create EDPM networker node VM
	$(eval $(call vars))
	scripts/gen-ansibleee-ssh-key.sh
	if [ ${EDPM_TOTAL_NETWORKERS} -eq 1 ]; then \
		scripts/gen-edpm-node.sh ${EDPM_NETWORKER_SUFFIX} '${EDPM_COMPUTE_ADDITIONAL_NETWORKS}'; \
	else \
		for INDEX in $(shell seq 0 $$((${EDPM_TOTAL_NETWORKERS} -1))) ; do \
			scripts/gen-edpm-node.sh $$INDEX '${EDPM_COMPUTE_ADDITIONAL_NETWORKS}' ; \
		done \
	fi

.PHONY: edpm_networker_cleanup
edpm_networker_cleanup: export EDPM_SERVER_ROLE=networker
edpm_networker_cleanup: ## Delete EDPM networker node VM
	$(eval $(call vars))
	if [ ${EDPM_TOTAL_NETWORKERS} -eq 1 ]; then \
		scripts/edpm-node-cleanup.sh ${EDPM_NETWORKER_SUFFIX}; \
	else \
		for INDEX in $(shell seq 0 $$((${EDPM_TOTAL_NETWORKERS} -1))) ; do \
			scripts/edpm-node-cleanup.sh $$INDEX ; \
		done \
	fi

.PHONY: edpm_deploy_instance
edpm_deploy_instance: export NO_OF_INSTANCES=${NUMBER_OF_INSTANCES}
edpm_deploy_instance: ## Spin a instance on edpm node
	-oc cp scripts/edpm-deploy-instance.sh openstackclient:/tmp/
	-oc rsh openstackclient bash /tmp/edpm-deploy-instance.sh ${NO_OF_INSTANCES}

.PHONY: tripleo_deploy
tripleo_deploy: export CLOUD_DOMAIN=${DNS_DOMAIN}
tripleo_deploy: export TLSE_ENABLED=${TLS_ENABLED}
tripleo_deploy: export INTERFACE_MTU=${NETWORK_MTU}
tripleo_deploy: export COMPUTE_CELLS=${EDPM_COMPUTE_CELLS}
tripleo_deploy: export REGISTRY_USER ?= ${RH_REGISTRY_USER}
tripleo_deploy: export REGISTRY_PWD ?= ${RH_REGISTRY_PWD}
tripleo_deploy: export COMPUTE_CEPH_ENABLED=${EDPM_COMPUTE_CEPH_ENABLED}
tripleo_deploy: export COMPUTE_CEPH_NOVA=${EDPM_COMPUTE_CEPH_NOVA}
tripleo_deploy: export TRIPLEO_NETWORKING=${EDPM_CONFIGURE_NETWORKING}
tripleo_deploy:
	$(eval $(call vars))
	scripts/tripleo.sh


.PHONY: standalone_deploy
standalone_deploy: export TLSE_ENABLED=${TLS_ENABLED}
standalone_deploy: export BARBICAN_ENABLED=${BARBICAN_SERVICE_ENABLED}
standalone_deploy: export MANILA_ENABLED=${MANILA_SERVICE_ENABLED}
standalone_deploy: export CLOUD_DOMAIN=${DNS_DOMAIN}
standalone_deploy: export COMPUTE_CEPH_ENABLED=${EDPM_COMPUTE_CEPH_ENABLED}
standalone_deploy: export CONFIGURE_HUGEPAGES=${EDPM_CONFIGURE_HUGEPAGES}
standalone_deploy: export COMPUTE_CEPH_NOVA=${EDPM_COMPUTE_CEPH_NOVA}
standalone_deploy: export COMPUTE_SRIOV_ENABLED=${EDPM_COMPUTE_SRIOV_ENABLED}
standalone_deploy: export COMPUTE_DHCP_AGENT_ENABLED=${EDPM_COMPUTE_DHCP_AGENT_ENABLED}
standalone_deploy: export STANDALONE=true
standalone_deploy: export INTERFACE_MTU=${NETWORK_MTU}
standalone_deploy: export EDPM_COMPUTE_NETWORK = ${NETWORK_ISOLATION_NET_NAME}
standalone_deploy:
	$(eval $(call vars))
	scripts/standalone.sh ${EDPM_COMPUTE_SUFFIX} ${STANDALONE_COMPUTE_DRIVER} '${EDPM_COMPUTE_ADDITIONAL_NETWORKS}' '${EDPM_COMPUTE_ADDITIONAL_HOST_ROUTES}'

.PHONY: standalone_sync
standalone_sync: export STANDALONE=true
standalone_sync: export EDPM_COMPUTE_NETWORK = ${NETWORK_ISOLATION_NET_NAME}
standalone_sync:
	$(eval $(call vars))
	scripts/standalone-sync.sh ${EDPM_COMPUTE_SUFFIX} ${STANDALONE_COMPUTE_DRIVER} '${EDPM_COMPUTE_ADDITIONAL_NETWORKS}' '${EDPM_COMPUTE_ADDITIONAL_HOST_ROUTES}'

.PHONY: standalone
standalone: export STANDALONE=true
standalone: edpm_compute standalone_deploy ## Create vm and deploy tripleo standalone
	$(eval $(call vars))
	make standalone_sync

.PHONY: standalone_cleanup
standalone_cleanup: export STANDALONE=true
standalone_cleanup: edpm_compute_cleanup ## Delete standalone VM
	$(eval $(call vars))

.PHONY: standalone_snapshot
standalone_snapshot: ## Create standalone snapshot
	$(eval $(call vars))
	virsh --connect=qemu:///system detach-device-alias edpm-compute-${EDPM_COMPUTE_SUFFIX} fs0 --live || true
	sleep 3
	virsh --connect=qemu:///system snapshot-create-as --atomic --domain edpm-compute-${EDPM_COMPUTE_SUFFIX} --name clean

.PHONY: standalone_revert
standalone_revert: ## Revert standalone snapshot
	$(eval $(call vars))
	virsh --connect=qemu:///system snapshot-revert --domain edpm-compute-${EDPM_COMPUTE_SUFFIX} --snapshotname clean
	make standalone_sync

.PHONY: cifmw_prepare
cifmw_prepare: ## Clone the ci-framework repository in the ci-framework directory. That location is ignored from git.
	git clone https://github.com/openstack-k8s-operators/ci-framework ${HOME}/ci-framework

.PHONY: cifmw_cleanup
cifmw_cleanup: ## Clean ci-framework git clone
	${CLEANUP_DIR_CMD} ${HOME}/ci-framework

##@ BMaaS/Ironic
.PHONY: bmaas_network
bmaas_network: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
ifeq ($(BMAAS_IPV4), true)
bmaas_network: export IPV4_ADDRESS = ${BMAAS_NETWORK_IPV4_PREFIX}
endif
ifeq ($(BMAAS_IPV6), true)
bmaas_network: export IPV6_ADDRESS = ${BMAAS_NETWORK_IPV6_PREFIX}
endif
bmaas_network: ## Create libvirt BMaaS network
	scripts/network-setup.sh --create

.PHONY: bmaas_network_cleanup
bmaas_network_cleanup: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_network_cleanup: ## Delete libvirt BMaaS network
	scripts/network-setup.sh --cleanup

.PHONY: bmaas_route_crc_and_crc_bmaas_networks
bmaas_route_crc_and_crc_bmaas_networks: export ROUTE_LIBVIRT_NETWORKS = ${BMAAS_ROUTE_LIBVIRT_NETWORKS}
bmaas_route_crc_and_crc_bmaas_networks:
	scripts/libvirt-network-routing.sh --create

.PHONY: bmaas_route_crc_and_crc_bmaas_networks_cleanup
bmaas_route_crc_and_crc_bmaas_networks_cleanup:
	scripts/libvirt-network-routing.sh --cleanup

.PHONY: bmaas_crc_attach_network
bmaas_crc_attach_network: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_crc_attach_network: export INSTANCE_NAME = ${BMAAS_OCP_INSTANCE_NAME}
bmaas_crc_attach_network: ## Attach BMaaS network to OCP VM ($INSTANCE_NAME)
	scripts/bmaas/attach-network.sh --create

.PHONY: bmaas_crc_attach_network_cleanup
bmaas_crc_attach_network_cleanup: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_crc_attach_network_cleanup: export INSTANCE_NAME = ${BMAAS_OCP_INSTANCE_NAME}
bmaas_crc_attach_network_cleanup: ## Detach BMaaS network from OCP VM ($INSTANCE_NAME)
	scripts/bmaas/attach-network.sh --cleanup

.PHONY: bmaas_crc_baremetal_bridge
bmaas_crc_baremetal_bridge: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_crc_baremetal_bridge: export INTERFACE_MTU = ${NETWORK_MTU}
bmaas_crc_baremetal_bridge: export BRIDGE_IP_PREFIX = ${BMAAS_BRIDGE_IP_PREFIX}
bmaas_crc_baremetal_bridge: export INSTANCE_NAME = ${BMAAS_OCP_INSTANCE_NAME}
ifeq ($(BMAAS_IPV4), true)
bmaas_crc_baremetal_bridge: export BRIDGE_IPV4_PREFIX = ${BMAAS_BRIDGE_IPV4_PREFIX}
endif
ifeq ($(BMAAS_IPV6), true)
bmaas_crc_baremetal_bridge: export BRIDGE_IPV6_PREFIX = ${BMAAS_BRIDGE_IPV6_PREFIX}
endif
bmaas_crc_baremetal_bridge:
	pushd .. && make nmstate && popd
	scripts/bmaas/baremetal-bridge.sh --create

.PHONY: bmaas_crc_baremetal_bridge_cleanup
bmaas_crc_baremetal_bridge_cleanup: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_crc_baremetal_bridge_cleanup:
	scripts/bmaas/baremetal-bridge.sh --cleanup

.PHONY: bmaas_baremetal_net_nad
bmaas_baremetal_net_nad:
	pushd .. && make namespace && popd
	scripts/bmaas/network-attachement-definition.sh --create

.PHONY: bmaas_baremetal_net_nad_cleanup
bmaas_baremetal_net_nad_cleanup:
	scripts/bmaas/network-attachement-definition.sh --cleanup

.PHONY: bmaas_metallb
bmaas_metallb: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_metallb: export POOL_NAME = ${BMAAS_METALLB_POOL_NAME}
bmaas_metallb: export ADDRESS_POOL = ${BMAAS_METALLB_ADDRESS_POOL}
bmaas_metallb:
	pushd .. && make metallb && popd
	scripts/bmaas/metallb.sh --create

.PHONY: bmaas_metallb_cleanup
bmaas_metallb_cleanup: export POOL_NAME = ${BMAAS_METALLB_POOL_NAME}
bmaas_metallb_cleanup:
	scripts/bmaas/metallb.sh --cleanup

.PHONY: bmaas_virtual_bms
bmaas_virtual_bms: export NODE_COUNT = ${BMAAS_NODE_COUNT}
bmaas_virtual_bms: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_virtual_bms: export NODE_NAME_PREFIX = ${BMAAS_INSTANCE_NAME_PREFIX}
bmaas_virtual_bms: export MEMORY = ${BMAAS_INSTANCE_MEMORY}
bmaas_virtual_bms: export VCPUS = ${BMAAS_INSTANCE_VCPUS}
bmaas_virtual_bms: export DISK_SIZE = ${BMAAS_INSTANCE_DISK_SIZE}
bmaas_virtual_bms: export OS_VARIANT = ${BMAAS_INSTANCE_OS_VARIANT}
bmaas_virtual_bms: export VIRT_TYPE = ${BMAAS_INSTANCE_VIRT_TYPE}
bmaas_virtual_bms: export NET_MODEL = ${BMAAS_INSTANCE_NET_MODEL}
bmaas_virtual_bms: ## Create libvirt VM for BMaaS
	scripts/bmaas/vbm-setup.sh --create

.PHONY: bmaas_virtual_bms_cleanup
bmaas_virtual_bms_cleanup: export NODE_COUNT = ${BMAAS_NODE_COUNT}
bmaas_virtual_bms_cleanup: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_virtual_bms_cleanup: export NODE_NAME_PREFIX = ${BMAAS_INSTANCE_NAME_PREFIX}
bmaas_virtual_bms_cleanup: export MEMORY = ${BMAAS_INSTANCE_MEMORY}
bmaas_virtual_bms_cleanup: export VCPUS = ${BMAAS_INSTANCE_VCPUS}
bmaas_virtual_bms_cleanup: export DISK_SIZE = ${BMAAS_INSTANCE_DISK_SIZE}
bmaas_virtual_bms_cleanup: export OS_VARIANT = ${BMAAS_INSTANCE_OS_VARIANT}
bmaas_virtual_bms_cleanup: export VIRT_TYPE = ${BMAAS_INSTANCE_VIRT_TYPE}
bmaas_virtual_bms_cleanup: export NET_MODEL = ${BMAAS_INSTANCE_NET_MODEL}
bmaas_virtual_bms_cleanup: ## Cleanup libvirt VM for BMaaS
	scripts/bmaas/vbm-setup.sh --cleanup

.PHONY: bmaas_sushy_emulator
bmaas_sushy_emulator: export NODE_NAME_PREFIX = ${BMAAS_INSTANCE_NAME_PREFIX}
bmaas_sushy_emulator: export LIBVIRT_USER = ${BMAAS_LIBVIRT_USER}
bmaas_sushy_emulator: export CRC_NETWORK_NAME = ${OCP_NETWORK_NAME}
bmaas_sushy_emulator: export BM_IPV6 = ${BMAAS_IPV6}
bmaas_sushy_emulator: export BM_IPV4 = ${BMAAS_IPV4}
bmaas_sushy_emulator: export SUSHY_EMULATOR_NAMESPACE = ${BMAAS_SUSHY_EMULATOR_NAMESPACE}
bmaas_sushy_emulator: export SUSHY_EMULATOR_DRIVER = ${BMAAS_SUSHY_EMULATOR_DRIVER}
bmaas_sushy_emulator: export SUSHY_EMULATOR_IMAGE = ${BMAAS_SUSHY_EMULATOR_IMAGE}
bmaas_sushy_emulator: export SUSHY_EMULATOR_OS_CLOUD = ${BMAAS_SUSHY_EMULATOR_OS_CLOUD}
bmaas_sushy_emulator: export SUSHY_EMULATOR_OS_CLIENT_CONFIG_FILE = ${BMAAS_SUSHY_EMULATOR_OS_CLIENT_CONFIG_FILE}
bmaas_sushy_emulator: export REDFISH_USERNAME = ${BMAAS_REDFISH_USERNAME}
bmaas_sushy_emulator: export REDFISH_PASSWORD = ${BMAAS_REDFISH_PASSWORD}
bmaas_sushy_emulator: ## Create BMaaS sushy-emulator (Virtual RedFish)
	scripts/bmaas/sushy-emulator.sh --create

.PHONY: bmaas_sushy_emulator_cleanup
bmaas_sushy_emulator_cleanup: export NODE_NAME_PREFIX = ${BMAAS_INSTANCE_NAME_PREFIX}
bmaas_sushy_emulator_cleanup: export LIBVIRT_USER = ${BMAAS_LIBVIRT_USER}
bmaas_sushy_emulator_cleanup: export SUSHY_EMULATOR_NAMESPACE = ${BMAAS_SUSHY_EMULATOR_NAMESPACE}
bmaas_sushy_emulator_cleanup: export SUSHY_EMULATOR_DRIVER = ${BMAAS_SUSHY_EMULATOR_DRIVER}
bmaas_sushy_emulator_cleanup: export SUSHY_EMULATOR_OS_CLOUD = ${BMAAS_SUSHY_EMULATOR_OS_CLOUD}
bmaas_sushy_emulator_cleanup: export REDFISH_USERNAME = ${BMAAS_REDFISH_USERNAME}
bmaas_sushy_emulator_cleanup: export REDFISH_PASSWORD = ${BMAAS_REDFISH_PASSWORD}
bmaas_sushy_emulator_cleanup: ## Cleanup BMaaS sushy-emulator (Virtual RedFish)
	scripts/bmaas/sushy-emulator.sh --cleanup

.PHONY: bmaas_sushy_emulator_wait
bmaas_sushy_emulator_wait: bmaas_sushy_emulator ## waits sushy-emulator to be ready
	bash -c 'oc -n ${BMAAS_SUSHY_EMULATOR_NAMESPACE} wait --for=condition=ready pod sushy-emulator --timeout=${TIMEOUT}'

.PHONY: bmaas_generate_nodes_yaml
bmaas_generate_nodes_yaml: export NODE_NAME_PREFIX = ${BMAAS_INSTANCE_NAME_PREFIX}
bmaas_generate_nodes_yaml: export REDFISH_USERNAME = ${BMAAS_REDFISH_USERNAME}
bmaas_generate_nodes_yaml: export REDFISH_PASSWORD = ${BMAAS_REDFISH_PASSWORD}
bmaas_generate_nodes_yaml: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_generate_nodes_yaml:
	scripts/bmaas/generate-nodes-yaml.sh

.PHONY: bmaas
bmaas: bmaas_cleanup
	make bmaas_network
	make bmaas_route_crc_and_crc_bmaas_networks
	make bmaas_crc_attach_network
	make bmaas_crc_baremetal_bridge
	make bmaas_baremetal_net_nad
	make bmaas_metallb
	make bmaas_virtual_bms
	make bmaas_sushy_emulator
	make bmaas_generate_nodes_yaml

.PHONY: bmaas_cleanup
bmaas_cleanup:
	make bmaas_sushy_emulator_cleanup
	make bmaas_virtual_bms_cleanup
	make bmaas_metallb_cleanup
	make bmaas_baremetal_net_nad_cleanup
	make bmaas_crc_baremetal_bridge_cleanup
	make bmaas_crc_attach_network_cleanup
	make bmaas_route_crc_and_crc_bmaas_networks_cleanup
	make bmaas_network_cleanup
