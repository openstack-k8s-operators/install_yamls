CRC_VERSION ?= latest
CRC_URL ?= 'https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/$(CRC_VERSION)/crc-linux-amd64.tar.xz'
KUBEADMIN_PWD ?= 12345678
PULL_SECRET  ?= ${PWD}/pull-secret.txt
CRC_DEFAULT_NETWORK_IP ?= 192.168.122.10
EDPM_COMPUTE_SUFFIX ?= 0
# EDPM_COMPUTE_ADDITIONAL_NETWORKS: JSON string - list of additional networks
# Examples:
#   cat << EOF
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
#   EDPM_COMPUTE_ADDITIONAL_NETWORKS=$(jq -c addtional_nets.json)
EDPM_COMPUTE_ADDITIONAL_NETWORKS ?= '[]'
EDPM_TOTAL_NODES ?= 1
NETWORK_MTU	?= 1500

BMAAS_INSTANCE_NAME_PREFIX ?= crc-bmaas
BMAAS_INSTANCE_MEMORY ?= 4096
BMAAS_INSTANCE_VCPUS ?= 2
BMAAS_INSTANCE_DISK_SIZE ?= 20
BMAAS_INSTANCE_OS_VARIANT ?= centos-stream9
BMAAS_INSTANCE_VIRT_TYPE ?= kvm
BMAAS_INSTANCE_NET_MODEL ?= virtio
BMAAS_NETWORK_NAME ?= crc-bmaas
BMAAS_BRIDGE_IPADDRESS ?= 172.20.1.2
BMAAS_NETWORK_IPADDRESS ?= 172.20.1.1
BMAAS_NETWORK_NETMASK ?= 255.255.255.0
BMAAS_NODE_COUNT ?= 1
BMAAS_REDFISH_USERNAME ?= admin
BMAAS_REDFISH_PASSWORD ?= password
BMAAS_SUSHY_EMULATOR_NAMESPACE ?= sushy-emulator
BMAAS_LIBVIRT_USER ?= sushyemu

DATAPLANE_REGISTRY_URL ?= quay.io/podified-antelope-centos9
DATAPLANE_CONTAINER_TAG ?= current-podified
DATAPLANE_PLAYBOOK ?= osp.edpm.download_cache
DATAPLANE_CHRONY_NTP_SERVER ?=pool.ntp.org
DATAPLANE_SSHD_ALLOWED_RANGES ?=['192.168.122.0/24']
DATAPLANE_CUSTOM_SERVICE_RUNNER_IMG ?=quay.io/openstack-k8s-operators/openstack-ansibleee-runner:latest
DATAPLANE_ANSIBLE_USER     ?=cloud-admin
DATAPLANE_ANSIBLE_SECRET   ?=dataplane-ansible-ssh-private-key-secret
DATAPLANE_GROWVOLS_ARGS    ?=/=8GB /tmp=1GB /home=1GB /var=8GB
BM_PROVISIONING_INTERFACE  ?=enp6s0
BM_CTLPLANE_INTERFACE      ?=enp1s0
BM_NETWORK_NAME            ?=default
BM_NETWORK_IPADDRESS       ?=192.168.122.1
BM_INSTANCE_NAME_PREFIX    ?=edpm-compute
BM_NODE_COUNT              ?=1
BM_ROOT_PASSWORD_SECRET    ?=
BMH_NAMESPACE              ?=openstack

STANDALONE_COMPUTE_DRIVER ?= libvirt

CLEANUP_DIR_CMD ?= rm -Rf

define vars
${1}: export CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD}
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
download_tools: ## Runs an ansible playbook to install required tools with the versions to develop the service operators. The tools get installed in ~/bin and go in /usr/local/go (alternatives get used to set it as the system wide go version)
	ANSIBLE_FORCE_COLOR=true ansible-playbook \
	-v -i hosts \
	download_tools.yaml

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

.PHONY: crc_attach_default_interface
crc_attach_default_interface: crc_attach_default_interface_cleanup ## Attach default libvirt network to CRC
	MAC_ADDRESS=$(shell echo -n 52:54:00; dd bs=1 count=3 if=/dev/random 2>/dev/null | hexdump -v -e '/1 "-%02X"' | tr '-' ':'); \
	virsh --connect=qemu:///system net-update default add-last ip-dhcp-host --xml "<host mac='$$MAC_ADDRESS' name='crc' ip='${CRC_DEFAULT_NETWORK_IP}'/>" --config --live; \
	virsh --connect=qemu:///system attach-interface crc --source default --type network --model virtio --mac $$MAC_ADDRESS --config --persistent; \
	sleep 10; \
	WORKER=$(shell oc get nodes -l node-role.kubernetes.io/worker -o jsonpath="{.items[*].metadata.name}"); \
	oc debug node/$$WORKER -- ip -o link | awk 'toupper($$0) ~ /ETHER $$MAC_ADDRESS/{print $$2}'  | awk -F: '{print $$1}'

.PHONY: crc_attach_default_interface_cleanup
crc_attach_default_interface_cleanup: ## Detach default libvirt network from CRC
	-MAC_ADDRESS=$(shell virsh --connect=qemu:///system net-dumpxml default | grep crc | sed -e "s/.*mac='\(.*\)' name.*/\1/"); \
	virsh --connect=qemu:///system detach-interface crc network --mac "$$MAC_ADDRESS"
	-virsh --connect=qemu:///system net-update default delete ip-dhcp-host "<host name='crc'/>" --config --live
	sleep 5

##@ EDPM

.PHONY: edpm_baremetal
edpm_baremetal: export EDPM_BMH_NAMESPACE=${BMH_NAMESPACE}
edpm_baremetal: export EDPM_PROVISIONING_INTERFACE=${BM_PROVISIONING_INTERFACE}
edpm_baremetal: export EDPM_CTLPLANE_INTERFACE=${BM_CTLPLANE_INTERFACE}
edpm_baremetal: export OPERATOR_NAME=openstack
edpm_baremetal: export EDPM_ANSIBLE_SECRET=${DATAPLANE_ANSIBLE_SECRET}
edpm_baremetal: export EDPM_ANSIBLE_USER=${DATAPLANE_ANSIBLE_USER}
edpm_baremetal: export BMAAS_NETWORK_NAME=${BM_NETWORK_NAME}
edpm_baremetal: export BMAAS_NETWORK_IPADDRESS=${BM_NETWORK_IPADDRESS}
edpm_baremetal: export BMAAS_INSTANCE_NAME_PREFIX=${BM_INSTANCE_NAME_PREFIX}
edpm_baremetal: export EDPM_CHRONY_NTP_SERVER=${DATAPLANE_CHRONY_NTP_SERVER}
edpm_baremetal: export EDPM_SSHD_ALLOWED_RANGES=${DATAPLANE_SSHD_ALLOWED_RANGES}
edpm_baremetal: export EDPM_ROOT_PASSWORD_SECRET=${BM_ROOT_PASSWORD_SECRET}
edpm_baremetal: export BMAAS_NODE_COUNT=${BM_NODE_COUNT}
edpm_baremetal: export NODE_COUNT=${BM_NODE_COUNT}
edpm_baremetal: export EDPM_TOTAL_NODES=${BM_NODE_COUNT}
edpm_baremetal: export OPENSTACK_RUNNER_IMG=${DATAPLANE_CUSTOM_SERVICE_RUNNER_IMG}
edpm_baremetal: export EDPM_REGISTRY_URL=${DATAPLANE_REGISTRY_URL}
edpm_baremetal: export EDPM_CONTAINER_TAG=${DATAPLANE_CONTAINER_TAG}
edpm_baremetal: export EDPM_GROWVOLS_ARGS=${DATAPLANE_GROWVOLS_ARGS}
edpm_baremetal: ## Deploy only dataplane with BMAAS
	$(eval $(call vars))
	make bmaas_virtual_bms
	make bmaas_sushy_emulator
	scripts/gen-ansibleee-ssh-key.sh
	scripts/edpm-compute-baremetal.sh --create

.PHONY: edpm_baremetal_cleanup
edpm_baremetal_cleanup: export BMAAS_NETWORK_NAME=${BM_NETWORK_NAME}
edpm_baremetal_cleanup: export BMAAS_INSTANCE_NAME_PREFIX=${BM_INSTANCE_NAME_PREFIX}
edpm_baremetal_cleanup: export BMAAS_NODE_COUNT=${BM_NODE_COUNT}
edpm_baremetal_cleanup: export NODE_COUNT=${BM_NODE_COUNT}
edpm_baremetal_cleanup:  ## Cleanup dataplane with BMAAS
	$(eval $(call vars))
	scripts/edpm-compute-baremetal.sh --cleanup
	pushd .. && rm -Rf out/edpm || true && popd
	make bmaas_sushy_emulator_cleanup || true
	make bmaas_virtual_bms_cleanup || true

.PHONY: edpm_compute
edpm_compute: ## Create EDPM compute VM
	$(eval $(call vars))
	scripts/gen-ansibleee-ssh-key.sh
	if [ ${EDPM_TOTAL_NODES} -eq 1 ]; then \
		scripts/gen-edpm-compute-node.sh ${EDPM_COMPUTE_SUFFIX} '${EDPM_COMPUTE_ADDITIONAL_NETWORKS}'; \
	else \
		for INDEX in $(shell seq 0 $$((${EDPM_TOTAL_NODES} -1))) ; do \
			scripts/gen-edpm-compute-node.sh $$INDEX '${EDPM_COMPUTE_ADDITIONAL_NETWORKS}' ; \
		done \
	fi

.PHONY: edpm_ansible_runner
edpm_ansible_runner: export EDPM_PLAYBOOK=${DATAPLANE_PLAYBOOK}
edpm_ansible_runner: export OPENSTACK_RUNNER_IMG=${DATAPLANE_CUSTOM_SERVICE_RUNNER_IMG}
edpm_ansible_runner: ## Debug edpm-ansible playbooks
	$(eval $(call vars))
	scripts/edpm-ansible-runner.sh

.PHONY: edpm_compute_repos
edpm_compute_repos: ## Configure EDPM compute VM with repositories
	$(eval $(call vars))
	scripts/edpm-compute-repos.sh ${EDPM_COMPUTE_SUFFIX}

.PHONY: edpm_compute_cleanup
edpm_compute_cleanup: ## Delete EDPM compute VM
	$(eval $(call vars))
	if [ ${EDPM_TOTAL_NODES} -eq 1 ]; then \
		scripts/edpm-compute-cleanup.sh ${EDPM_COMPUTE_SUFFIX}; \
	else \
		for INDEX in $(shell seq 0 $$((${EDPM_TOTAL_NODES} -1))) ; do \
			scripts/edpm-compute-cleanup.sh $$INDEX ; \
		done \
	fi

.PHONY: edpm_deploy_instance
edpm_deploy_instance: ## Spin a instance on edpm node
	-oc cp scripts/edpm-deploy-instance.sh openstackclient:/tmp/
	-oc rsh openstackclient bash /tmp/edpm-deploy-instance.sh

.PHONY: standalone
standalone: export STANDALONE=true
standalone: export INTERFACE_MTU=${NETWORK_MTU}
standalone: edpm_compute ## Create standalone VM
	$(eval $(call vars))
	scripts/standalone.sh ${EDPM_COMPUTE_SUFFIX} ${STANDALONE_COMPUTE_DRIVER} '${EDPM_COMPUTE_ADDITIONAL_NETWORKS}'

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

.PHONY: cifmw_prepare
cifmw_prepare: ## Clone the ci-framework repository in the ci-framework directory. That location is ignored from git.
	git clone https://github.com/openstack-k8s-operators/ci-framework $HOME/ci-framework

.PHONY: cifmw_cleanup
cifmw_cleanup: ## Clean ci-framework git clone
	${CLEANUP_DIR_CMD} $HOME/ci-framework

##@ BMaaS/Ironic
.PHONY: bmaas_network
bmaas_network: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_network: export NETWORK_IPADDRESS = ${BMAAS_NETWORK_IPADDRESS}
bmaas_network: export NETWORK_NETMASK = ${BMAAS_NETWORK_NETMASK}
bmaas_network: ## Create libvirt BMaaS network
	scripts/network-setup.sh --create

.PHONY: bmaas_network_cleanup
bmaas_network_cleanup: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_network_cleanup: export NETWORK_IPADDRESS = ${BMAAS_NETWORK_IPADDRESS}
bmaas_network_cleanup: export NETWORK_NETMASK = ${BMAAS_NETWORK_NETMASK}
bmaas_network_cleanup: ## Delete libvirt BMaaS network
	scripts/network-setup.sh --cleanup

.PHONY: bmaas_crc_attach_network
bmaas_crc_attach_network: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_crc_attach_network: ## Attach BMaaS network to CRC
	scripts/bmaas/attach-network.sh --create

.PHONY: bmaas_crc_attach_network_cleanup
bmaas_crc_attach_network_cleanup: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_crc_attach_network_cleanup: ## Detach BMaaS network from CRC
	scripts/bmaas/attach-network.sh --cleanup

.PHONY: bmaas_crc_baremetal_bridge
bmaas_crc_baremetal_bridge: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_crc_baremetal_bridge: export INTERFACE_MTU = ${NETWORK_MTU}
bmaas_crc_baremetal_bridge:
	scripts/bmaas/baremetal-bridge.sh --create

.PHONY: bmaas_crc_baremetal_bridge_cleanup
bmaas_crc_baremetal_bridge_cleanup: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_crc_baremetal_bridge_cleanup:
	scripts/bmaas/baremetal-bridge.sh --cleanup

.PHONY: bmaas_baremetal_net_nad
bmaas_baremetal_net_nad:
	scripts/bmaas/network-attachement-definition.sh --create

.PHONY: bmaas_baremetal_net_nad_cleanup
bmaas_baremetal_net_nad_cleanup:
	scripts/bmaas/network-attachement-definition.sh --cleanup

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
bmaas_sushy_emulator: export SUSHY_EMULATOR_NAMESPACE = ${BMAAS_SUSHY_EMULATOR_NAMESPACE}
bmaas_sushy_emulator: export REDFISH_USERNAME = ${BMAAS_REDFISH_USERNAME}
bmaas_sushy_emulator: export REDFISH_PASSWORD = ${BMAAS_REDFISH_PASSWORD}
bmaas_sushy_emulator: ## Create BMaaS sushy-emulator (Virtual RedFish)
	scripts/bmaas/sushy-emulator.sh --create

.PHONY: bmaas_sushy_emulator_cleanup
bmaas_sushy_emulator_cleanup: export NODE_NAME_PREFIX = ${BMAAS_INSTANCE_NAME_PREFIX}
bmaas_sushy_emulator_cleanup: export LIBVIRT_USER = ${BMAAS_LIBVIRT_USER}
bmaas_sushy_emulator_cleanup: export SUSHY_EMULATOR_NAMESPACE = ${BMAAS_SUSHY_EMULATOR_NAMESPACE}
bmaas_sushy_emulator_cleanup: export REDFISH_USERNAME = ${BMAAS_REDFISH_USERNAME}
bmaas_sushy_emulator_cleanup: export REDFISH_PASSWORD = ${BMAAS_REDFISH_PASSWORD}
bmaas_sushy_emulator_cleanup: ## Cleanup BMaaS sushy-emulator (Virtual RedFish)
	scripts/bmaas/sushy-emulator.sh --cleanup

.PHONY: bmaas_generate_nodes_yaml
bmaas_generate_nodes_yaml: export NODE_NAME_PREFIX = ${BMAAS_INSTANCE_NAME_PREFIX}
bmaas_generate_nodes_yaml: export REDFISH_USERNAME = ${BMAAS_REDFISH_USERNAME}
bmaas_generate_nodes_yaml: export REDFISH_PASSWORD = ${BMAAS_REDFISH_PASSWORD}
bmaas_generate_nodes_yaml: export NETWORK_NAME = ${BMAAS_NETWORK_NAME}
bmaas_generate_nodes_yaml:
	scripts/bmaas/generate-nodes-yaml.sh

.PHONY: bmaas
bmaas: bmaas_cleanup
	pushd .. && make input nmstate && popd
	make bmaas_network
	make bmaas_crc_attach_network
	make bmaas_crc_baremetal_bridge
	make bmaas_baremetal_net_nad
	make bmaas_virtual_bms
	make bmaas_sushy_emulator
	make bmaas_generate_nodes_yaml

.PHONY: bmaas_cleanup
bmaas_cleanup:
	make bmaas_sushy_emulator_cleanup
	make bmaas_virtual_bms_cleanup
	make bmaas_baremetal_net_nad_cleanup
	make bmaas_crc_baremetal_bridge_cleanup
	make bmaas_crc_attach_network_cleanup
	make bmaas_network_cleanup
