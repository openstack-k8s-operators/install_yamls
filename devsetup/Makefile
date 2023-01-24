CRC_URL ?= 'https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz'
KUBEADMIN_PWD ?= 12345678
PULL_SECRET  ?= ${PWD}/pull-secret.txt
EDPM_COMPUTE_SUFFIX ?= 0

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

##@ CRC
.PHONY: crc
crc: ## Deploys CRC using CRC_URL to download and install CRC, KUBEADMIN_PWD as the password which defaults to 12345678 and PULL_SECRET to specify the file containing the pull secret, defaults to ${PWD}/pull-secret.txt. To change the default memory and/or cpus for the VM use `CPUS=X MEMORY=Y make crc`.
	bash scripts/crc-setup.sh ${CRC_URL} ${KUBEADMIN_PWD} ${PULL_SECRET}

.PHONY: crc_cleanup
crc_cleanup: ## Destroys the CRC env, but does NOT clear ( --clear-cache ) the cache to save time on next setup.
	crc delete --force
	crc cleanup
	sudo rm -f /etc/pki/ca-trust/source/anchors/crc-router-ca.pem
	sudo update-ca-trust

##@ Download required tools and versions
.PHONY: download_tools
download_tools: ## Runs an ansible playbook to install required tools with the versions to develop the service operators. The tools get installed in ~/bin and go in /usr/local/go (alternatives get used to set it as the system wide go version)
	ANSIBLE_FORCE_COLOR=true ansible-playbook \
	-v -i hosts \
	download_tools.yaml

.PHONY: crc_attach_default_interface
crc_attach_default_interface:
	sudo virsh attach-interface crc --source default --type network --model virtio --config --persistent

.PHONY: edpm_compute
edpm_compute:
	scripts/gen-ansibleee-ssh-key.sh
	scripts/gen-edpm-compute-node.sh ${EDPM_COMPUTE_SUFFIX}

.PHONY: edpm_compute_cleanup
edpm_compute_cleanup:
	-sudo virsh destroy edpm-compute-${EDPM_COMPUTE_SUFFIX}
	-sudo virsh undefine edpm-compute-${EDPM_COMPUTE_SUFFIX}
	rm -f ${HOME}/.crc/machines/crc/edpm-compute-${EDPM_COMPUTE_SUFFIX}.qcow2

.PHONY: edpm_play
edpm_play:
	oc create -f edpm/edpm-play.yaml

.PHONY: edpm_play_cleanup
edpm_play_cleanup:
	-oc delete ansibleee deploy-external-dataplane-compute
