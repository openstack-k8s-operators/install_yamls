NAMESPACE ?= openstack
KEYSTONE_IMG ?= quay.io/openstack-k8s-operators/keystone-operator-index:latest
MARIADB_IMG ?= quay.io/openstack-k8s-operators/mariadb-operator-index:latest

.PHONY: all
all: namespace keystone mariadb

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
crc_storage: ## initialize local storage PVs in CRC vm
	bash scripts/create-pv.sh
	bash scripts/gen-crc-pv-kustomize.sh
	oc kustomize out/crc | oc apply -f -

crc_storage_cleanup: ## cleanup local storage PVs in CRC vm
	oc get pv | grep local | cut -f 1 -d ' ' | xargs oc delete pv
	oc delete sc local-storage
	#FIXME need to cleanup the actual directories in the CRC VM too

##@ NAMESPACE
.PHONY: namespace
namespace: ## creates the namespace specified via NAMESPACE env var (defaults to openstack)
	bash scripts/gen-namespace.sh ${NAMESPACE}
	oc apply -f out/${NAMESPACE}/namespace.yaml
	sleep 2
	oc project ${NAMESPACE}

.PHONY: namespace_cleanup
namespace_cleanup: ## deletes the namespace specified via NAMESPACE env var, also runs cleanup for all services to cleanup the namespace prior delete it.
	make keystone_cleanup
	make mariadb_cleanup
	oc delete project ${NAMESPACE}
	rm -Rf out/${NAMESPACE}

##@ KEYSTONE
.PHONY: keystone_prep
keystone_prep: ## creates the files to install the operator using olm
	bash scripts/gen-olm.sh ${NAMESPACE} keystone ${KEYSTONE_IMG}

.PHONY: keystone
keystone: namespace keystone_prep ## installs the operator, also runs the prep step
	oc apply -f out/${NAMESPACE}/keystone

.PHONY: keystone_cleanup
keystone_cleanup: ## deletes the operator, but does not cleanup the service resources
	oc delete --ignore-not-found=true -f out/${NAMESPACE}/keystone
	rm -Rf out/${NAMESPACE}/keystone

##@ MARIADB
mariadb_prep: ## creates the files to install the operator using olm
	bash scripts/gen-olm.sh ${NAMESPACE} mariadb ${MARIADB_IMG}

.PHONY: mariadb
mariadb: namespace mariadb_prep ## installs the operator, also runs the prep step
	oc apply -f out/${NAMESPACE}/mariadb

.PHONY: mariadb_cleanup
mariadb_cleanup: ## deletes the operator, but does not cleanup the service resources
	oc delete --ignore-not-found=true -f out/${NAMESPACE}/mariadb
	rm -Rf out/${NAMESPACE}/mariadb
