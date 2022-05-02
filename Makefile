KEYSTONE_IMG=quay.io/openstack-k8s-operators/keystone-operator-index:latest
MARIADB_IMG=quay.io/openstack-k8s-operators/mariadb-operator-index:latest

all: keystone mariadb

crc_storage:
	bash scripts/create-pv.sh
	bash scripts/gen-crc-pv-kustomize.sh
	oc kustomize out/crc | oc apply -f -

# KEYSTONE
out/keystone/subscription.yaml:
	bash scripts/gen-olm.sh keystone ${KEYSTONE_IMG}

.PHONY: keystone
keystone: out/keystone/subscription.yaml
	oc apply -f out/keystone

.PHONY: keystone_cleanup
keystone_cleanup: 
	oc delete -n openstack csv keystone-operator.v0.0.1 || true
	oc delete -n openstack subscription keystone-operator || true
	oc delete -n openstack catalogsource keystone-operator-index || true
	rm -Rf out/keystone

# MARIADB
out/mariadb/subscription.yaml:
	bash scripts/gen-olm.sh mariadb ${MARIADB_IMG}

.PHONY: mariadb
mariadb: out/mariadb/subscription.yaml
	oc apply -f out/mariadb

.PHONY: mariadb_cleanup
mariadb_cleanup: 
	oc delete -n openstack csv mariadb-operator.v0.0.1 || true
	oc delete -n openstack subscription mariadb-operator || true
	oc delete -n openstack catalogsource mariadb-operator-index || true
	rm -Rf out/mariadb
