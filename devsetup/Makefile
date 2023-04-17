CRC_URL ?= 'https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz'
KUBEADMIN_PWD ?= 12345678
PULL_SECRET  ?= ${PWD}/pull-secret.txt
CRC_DEFAULT_NETWORK_IP ?= 192.168.122.10
EDPM_COMPUTE_SUFFIX ?= 0
EDPM_COMPUTE_IP ?= 192.168.122.100
OPENSTACK_RUNNER_IMG ?= quay.io/openstack-k8s-operators/openstack-ansibleee-runner:latest
EDPM_NETWORK_CONFIG_TEMPLATE ?= templates/single_nic_vlans/single_nic_vlans.j2
EDPM_SSHD_ALLOWED_RANGES ?= ['192.168.122.0/24']
EDPM_CHRONY_NTP_SERVER ?= pool.ntp.org
EDPM_PLAY_CRD ?= edpm/edpm-play.yaml

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
	sudo rm -f /etc/pki/ca-trust/source/anchors/crc-router-ca.pem
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
.PHONY: edpm_compute
edpm_compute: ## Create EDPM compute VM
	scripts/gen-ansibleee-ssh-key.sh
	scripts/gen-edpm-compute-node.sh ${EDPM_COMPUTE_SUFFIX}

.PHONY: edpm_compute_repos
edpm_compute_repos: ## Configure EDPM compute VM with repositories
	scripts/edpm-compute-repos.sh ${EDPM_COMPUTE_SUFFIX}

.PHONY: edpm_compute_cleanup
edpm_compute_cleanup: ## Delete EDPM compute VM
	scripts/edpm-compute-cleanup.sh ${EDPM_COMPUTE_SUFFIX}

.PHONY: edpm_play
edpm_play: export EDPM_OVN_METADATA_AGENT_TRANSPORT_URL=$(shell oc get secret rabbitmq-transport-url-neutron-neutron-transport -o json | jq -r .data.transport_url | base64 -d)
edpm_play: export EDPM_OVN_METADATA_AGENT_SB_CONNECTION=$(shell oc get ovndbcluster ovndbcluster-sb -o json | jq -r .status.dbAddress)
edpm_play: export EDPM_OVN_DBS=$(shell oc get ovndbcluster ovndbcluster-sb -o json | jq -r '.status.networkAttachments."openstack/internalapi"[0]')
edpm_play: export EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST=127.0.0.1
edpm_play: export EDPM_OVN_METADATA_AGENT_PROXY_SHARED_SECRET=12345678
edpm_play: export EDPM_OVN_METADATA_AGENT_BIND_HOST=127.0.0.1
edpm_play: export EDPM_NOVA_NOTIFICATIONS_TRANSPORT_URL=$(shell oc get secret rabbitmq-transport-url-nova-api-transport -o json | jq -r .data.transport_url | base64 -d)
edpm_play: export EDPM_NOVA_COMPUTE_TRANSPORT_URL=$(shell oc get secret rabbitmq-transport-url-cell1-transport -o json | jq -r .data.transport_url | base64 -d)
edpm_play: ## Deploy EDPM node using openstackansibleee resource
	scripts/gen-ansibleee-ssh-key.sh
	sed -e "s|_COMPUTE_IP_|${EDPM_COMPUTE_IP}|g" \
	    -e "s|_OPENSTACK_RUNNER_IMG_|${OPENSTACK_RUNNER_IMG}|g" \
	    -e "s|_EDPM_NETWORK_CONFIG_TEMPLATE_|${EDPM_NETWORK_CONFIG_TEMPLATE}|g" \
	    -e "s|_EDPM_SSHD_ALLOWED_RANGES_|${EDPM_SSHD_ALLOWED_RANGES}|g" \
	    -e "s|_EDPM_CHRONY_NTP_SERVER_|${EDPM_CHRONY_NTP_SERVER}|g" \
	    -e "s|_EDPM_OVN_METADATA_AGENT_TRANSPORT_URL_|${EDPM_OVN_METADATA_AGENT_TRANSPORT_URL}|g" \
	    -e "s|_EDPM_OVN_METADATA_AGENT_SB_CONNECTION_|${EDPM_OVN_METADATA_AGENT_SB_CONNECTION}|g" \
	    -e "s|_EDPM_OVN_DBS_|${EDPM_OVN_DBS}|g" \
	    -e "s|_EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST_|${EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST}|g" \
	    -e "s|_EDPM_OVN_METADATA_AGENT_PROXY_SHARED_SECRET_|${EDPM_OVN_METADATA_AGENT_PROXY_SHARED_SECRET}|g" \
	    -e "s|_EDPM_OVN_METADATA_AGENT_BIND_HOST_|${EDPM_OVN_METADATA_AGENT_BIND_HOST}|g" \
	    -e "s|_EDPM_NOVA_COMPUTE_TRANSPORT_URL_|${EDPM_NOVA_COMPUTE_TRANSPORT_URL}|g" \
	    -e "s|_EDPM_NOVA_NOTIFICATIONS_TRANSPORT_URL_|${EDPM_NOVA_NOTIFICATIONS_TRANSPORT_URL}|g" \
	    ${EDPM_PLAY_CRD} | oc create -f -

.PHONY: edpm_deploy_instance
edpm_deploy_instance: ## Spin a instance on edpm node
	-oc rsh openstackclient sudo touch /dev/log && ls /dev/log # Workaround for lp/1999553
	-oc cp scripts/edpm-deploy-instance.sh openstackclient:/tmp/
	-oc rsh openstackclient bash /tmp/edpm-deploy-instance.sh

.PHONY: edpm_play_cleanup
edpm_play_cleanup: ## Cleanup EDPM openstackansibleee resource
	-oc delete openstackansibleee deploy-external-dataplane-compute

.PHONY: cifmw_prepare
cifmw_prepare: ## Clone the ci-framework repository in the ci-framework directory. That location is ignored from git.
	git clone https://github.com/openstack-k8s-operators/ci-framework ci-framework

.PHONY: cifmw_cleanup
cifmw_cleanup: ## Clean ci-framework git clone
	rm -rf ci-framework
