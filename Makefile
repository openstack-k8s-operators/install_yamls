# general
SHELL       := /bin/bash
OKD                      ?= false
OPERATOR_NAMESPACE      ?= openstack-operators
NAMESPACE                ?= openstack
PASSWORD                 ?= 12345678
SECRET                   ?= osp-secret
LIBVIRT_SECRET           ?= libvirt-secret
OUT                      ?= ${PWD}/out
TIMEOUT                  ?= 300s
BAREMETAL_TIMEOUT        ?= 20m
DBSERVICE           ?= galera
ifeq ($(DBSERVICE), galera)
DBSERVICE_CONTAINER = openstack-galera-0
else
DBSERVICE_CONTAINER = mariadb-openstack
endif
METADATA_SHARED_SECRET   ?= 1234567842
HEAT_AUTH_ENCRYPTION_KEY ?= 767c3ed056cbaa3b9dfedb8c6f825bf0
OPENSTACK_K8S_BRANCH     ?= main
OPENSTACK_K8S_TAG        ?= latest

# Use Red Hat operators from OpenShift Marketplace
REDHAT_OPERATORS		 ?= false
ifeq ($(REDHAT_OPERATORS), true)
	OPERATOR_CHANNEL		 	?= stable-v1.0
	OPERATOR_SOURCE		 		?= redhat-operators
	OPERATOR_SOURCE_NAMESPACE	?= openshift-marketplace
endif

# Barbican encryption key should be a random 32-byte string that is base64
# encoded.  e.g. head --bytes=32 /dev/urandom | base64
BARBICAN_SIMPLE_CRYPTO_ENCRYPTION_KEY ?= sEFmdFjDUqRM2VemYslV5yGNWjokioJXsg8Nrlc3drU=
KEYSTONE_FEDERATION_CLIENT_SECRET ?= COX8bmlKAWn56XCGMrKQJj7dgHNAOl6f
KEYSTONE_CRYPTO_PASSPHRASE ?= openstack

# Allows overriding the cleanup command used in *_cleanup targets.
# Useful in CI, to allow injectin kustomization in each operator CR directory
# before the resource gets deployed. If it's not possible to inject Kustomizations/CRs
# in the CR dir if a call to each deploy target cleans the CR dir.
CLEANUP_DIR_CMD					 ?= rm -Rf

# When cloning operator's repo, enables the checkout from commit hash
# that is referenced in openstack-operator's go.mod. Note that openstack-opearator
# code can exist in OPERATOR_BASE_DIR/openstack-operator path, otherwise it will
# be also cloned from OPENSTACK_REPO/OPENSTACK_BRANCH.
CHECKOUT_FROM_OPENSTACK_REF	?= false

NETWORK_INTERNALAPI_ADDRESS_PREFIX 	?= 172.17.0
NETWORK_STORAGE_ADDRESS_PREFIX 	?= 172.18.0
NETWORK_TENANT_ADDRESS_PREFIX 	?= 172.19.0
NETWORK_STORAGEMGMT_ADDRESS_PREFIX 	?= 172.20.0
NETWORK_DESIGNATE_ADDRESS_PREFIX 	?= 172.28.0
INTERNALAPI_HOST_ROUTES ?=
STORAGE_HOST_ROUTES ?=
TENANT_HOST_ROUTES ?=
STORAGEMGMT_HOST_ROUTES ?=

# network isolation
NETWORK_ISOLATION   ?= true
NETWORK_ISOLATION_USE_DEFAULT_NETWORK ?= true
NETWORK_ISOLATION_IPV4 ?= true
NETWORK_ISOLATION_IPV6 ?= false
NETWORK_MTU         ?= 1500
NETWORK_VLAN_START  ?= 20
NETWORK_VLAN_STEP   ?= 1
NETWORK_ISOLATION_IPV4_ADDRESS ?= 172.16.1.1/24
NETWORK_ISOLATION_IPV6_ADDRESS ?= fd00:aaaa::1/64

# This creates a macvlan on the host network namespace on top of the storage VLAN
# to allow host to/from pod network communication on the same host using that VLAN.
# An example when this is useful is when using Cinder Volume with LVM + iSCSI
# without using the host's IP address.
NETWORK_STORAGE_MACVLAN ?=

# are we deploying to microshift
MICROSHIFT ?= 0

# operators gets cloned here
OPERATOR_BASE_DIR   ?= ${OUT}/operator

# storage (used by some operators)
STORAGE_CLASS       ?= "local-storage"
CRC_STORAGE_RETRIES ?= 3
LVMS_CR ?= 1

# options to pass in all targets that use git clone
GIT_CLONE_OPTS      ?=

# set to 3 to use a 3-node galera sample
GALERA_REPLICAS         ?=

# OpenStack Operator
OPENSTACK_IMG                ?= quay.io/openstack-k8s-operators/openstack-operator-index:${OPENSTACK_K8S_TAG}
OPENSTACK_REPO               ?= https://github.com/openstack-k8s-operators/openstack-operator.git
OPENSTACK_BRANCH             ?= ${OPENSTACK_K8S_BRANCH}
OPENSTACK_COMMIT_HASH        ?=

ifeq ($(NETWORK_ISOLATION), true)
ifeq ($(DBSERVICE), galera)
OPENSTACK_CTLPLANE           ?= $(if $(findstring 3,$(GALERA_REPLICAS)),config/samples/core_v1beta1_openstackcontrolplane_galera_network_isolation_3replicas.yaml,config/samples/core_v1beta1_openstackcontrolplane_galera_network_isolation.yaml)
else
OPENSTACK_CTLPLANE           ?= config/samples/core_v1beta1_openstackcontrolplane_network_isolation.yaml
endif
else
ifeq ($(DBSERVICE), galera)
OPENSTACK_CTLPLANE           ?= $(if $(findstring 3,$(GALERA_REPLICAS)),config/samples/core_v1beta1_openstackcontrolplane_galera_3replicas.yaml,config/samples/core_v1beta1_openstackcontrolplane_galera.yaml)
else
OPENSTACK_CTLPLANE           ?= config/samples/core_v1beta1_openstackcontrolplane.yaml
endif
endif

OPENSTACK_CR                 ?= ${OPERATOR_BASE_DIR}/openstack-operator/${OPENSTACK_CTLPLANE}
OPENSTACK_BUNDLE_IMG         ?= quay.io/openstack-k8s-operators/openstack-operator-bundle:${OPENSTACK_K8S_TAG}
OPENSTACK_STORAGE_BUNDLE_IMG ?= quay.io/openstack-k8s-operators/openstack-operator-storage-bundle:${OPENSTACK_K8S_TAG}
OPENSTACK_CRDS_DIR           ?= openstack_crds
OPENSTACK_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/openstack-operator/kuttl-test.yaml
OPENSTACK_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/openstack-operator/tests/kuttl/tests
OPENSTACK_KUTTL_NAMESPACE ?= openstack-kuttl-tests

# Infra Operator
INFRA_IMG             ?= quay.io/openstack-k8s-operators/infra-operator-index:${OPENSTACK_K8S_TAG}
INFRA_REPO            ?= https://github.com/openstack-k8s-operators/infra-operator.git
INFRA_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
INFRA_COMMIT_HASH     ?=
INFRA_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/infra-operator/kuttl-test.yaml
INFRA_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/infra-operator/tests/kuttl/tests
INFRA_KUTTL_NAMESPACE ?= infra-kuttl-tests

# DNS
# DNS_IMG     ?= (this is unused because this is part of infra operator)
DNSMASQ       ?= config/samples/network_v1beta1_dnsmasq.yaml
DNSDATA       ?= config/samples/network_v1beta1_dnsdata.yaml
DNSMASQ_CR    ?= ${OPERATOR_BASE_DIR}/infra-operator/${DNSMASQ}
DNSDATA_CR    ?= ${OPERATOR_BASE_DIR}/infra-operator/${DNSDATA}
DNS_DEPL_IMG  ?= unused

# NetConfig
NETCONFIG     ?= config/samples/network_v1beta1_netconfig.yaml
NETCONFIG_CR  ?= ${OPERATOR_BASE_DIR}/infra-operator/${NETCONFIG}
NETCONFIG_DEPL_IMG  ?= unused

# Memcached
# MEMCACHED_IMG     ?= (this is unused because this is part of infra operator)
MEMCACHED           ?= config/samples/memcached_v1beta1_memcached.yaml
MEMCACHED_CR        ?= ${OPERATOR_BASE_DIR}/infra-operator/${MEMCACHED}
MEMCACHED_DEPL_IMG  ?= unused

# Keystone
KEYSTONE_IMG             ?= quay.io/openstack-k8s-operators/keystone-operator-index:${OPENSTACK_K8S_TAG}
KEYSTONE_REPO            ?= https://github.com/openstack-k8s-operators/keystone-operator.git
KEYSTONE_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
KEYSTONE_COMMMIT_HASH    ?=
KEYSTONEAPI              ?= config/samples/keystone_v1beta1_keystoneapi.yaml
KEYSTONEAPI_CR           ?= ${OPERATOR_BASE_DIR}/keystone-operator/${KEYSTONEAPI}
KEYSTONEAPI_DEPL_IMG     ?= unused
KEYSTONE_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/keystone-operator/kuttl-test.yaml
KEYSTONE_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/keystone-operator/tests/kuttl/tests
KEYSTONE_KUTTL_NAMESPACE ?= keystone-kuttl-tests

# Barbican
BARBICAN_IMG             ?= quay.io/openstack-k8s-operators/barbican-operator-index:latest
BARBICAN_REPO            ?= https://github.com/openstack-k8s-operators/barbican-operator.git
BARBICAN_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
BARBICAN_COMMIT_HASH     ?=
BARBICAN                 ?= config/samples/barbican_v1beta1_barbican.yaml
BARBICAN_CR              ?= ${OPERATOR_BASE_DIR}/barbican-operator/${BARBICAN}
BARBICAN_DEPL_IMG        ?= unused
BARBICAN_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/barbican-operator/kuttl-test.yaml
BARBICAN_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/barbican-operator/tests/kuttl/tests
BARBICAN_KUTTL_NAMESPACE ?= barbican-kuttl-tests

# Mariadb
MARIADB_IMG             ?= quay.io/openstack-k8s-operators/mariadb-operator-index:${OPENSTACK_K8S_TAG}
MARIADB_REPO            ?= https://github.com/openstack-k8s-operators/mariadb-operator.git
MARIADB_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
MARIADB_COMMIT_HASH     ?=
ifeq ($(DBSERVICE), galera)
MARIADB                 ?= config/samples/mariadb_v1beta1_galera.yaml
else
MARIADB                 ?= config/samples/mariadb_v1beta1_mariadb.yaml
endif
MARIADB_CR              ?= ${OPERATOR_BASE_DIR}/mariadb-operator/${MARIADB}
MARIADB_DEPL_IMG        ?= unused
MARIADB_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/mariadb-operator/kuttl-test.yaml
MARIADB_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/mariadb-operator/tests/kuttl/tests
MARIADB_KUTTL_NAMESPACE ?= mariadb-kuttl-tests

# Placement
PLACEMENT_IMG             ?= quay.io/openstack-k8s-operators/placement-operator-index:${OPENSTACK_K8S_TAG}
PLACEMENT_REPO            ?= https://github.com/openstack-k8s-operators/placement-operator.git
PLACEMENT_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
PLACEMENT_COMMIT_HASH     ?=
PLACEMENTAPI              ?= config/samples/placement_v1beta1_placementapi.yaml
PLACEMENTAPI_CR           ?= ${OPERATOR_BASE_DIR}/placement-operator/${PLACEMENTAPI}
PLACEMENTAPI_DEPL_IMG     ?= unused
PLACEMENT_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/placement-operator/kuttl-test.yaml
PLACEMENT_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/placement-operator/tests/kuttl/tests
PLACEMENT_KUTTL_NAMESPACE ?= placement-kuttl-tests

# Sir Glancealot
GLANCE_IMG              ?= quay.io/openstack-k8s-operators/glance-operator-index:${OPENSTACK_K8S_TAG}
GLANCE_REPO             ?= https://github.com/openstack-k8s-operators/glance-operator.git
GLANCE_BRANCH           ?= ${OPENSTACK_K8S_BRANCH}
GLANCE_COMMIT_HASH      ?=
GLANCE                  ?= config/samples/glance_v1beta1_glance.yaml
GLANCE_CR               ?= ${OPERATOR_BASE_DIR}/glance-operator/${GLANCE}
GLANCEAPI_DEPL_IMG      ?= unused
GLANCE_KUTTL_CONF       ?= ${OPERATOR_BASE_DIR}/glance-operator/kuttl-test.yaml
GLANCE_KUTTL_DIR        ?= ${OPERATOR_BASE_DIR}/glance-operator/test/kuttl/tests
GLANCE_KUTTL_NAMESPACE  ?= glance-kuttl-tests

# Ovn
OVN_IMG             ?= quay.io/openstack-k8s-operators/ovn-operator-index:${OPENSTACK_K8S_TAG}
OVN_REPO            ?= https://github.com/openstack-k8s-operators/ovn-operator.git
OVN_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
OVN_COMMIT_HASH     ?=
OVNDBS              ?= config/samples/ovn_v1beta1_ovndbcluster.yaml
OVNDBS_CR           ?= ${OPERATOR_BASE_DIR}/ovn-operator/${OVNDBS}
OVNNORTHD           ?= config/samples/ovn_v1beta1_ovnnorthd.yaml
OVNNORTHD_CR        ?= ${OPERATOR_BASE_DIR}/ovn-operator/${OVNNORTHD}
OVNCONTROLLER       ?= config/samples/ovn_v1beta1_ovncontroller.yaml
OVNCONTROLLER_CR    ?= ${OPERATOR_BASE_DIR}/ovn-operator/${OVNCONTROLLER}
OVNCONTROLLER_NMAP  ?= ${NETWORK_ISOLATION}
# TODO: Image customizations for all OVN services
OVN_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/ovn-operator/kuttl-test.yaml
OVN_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/ovn-operator/tests/kuttl/tests
OVN_KUTTL_NAMESPACE ?= ovn-kuttl-tests

# Neutron
NEUTRON_IMG             ?= quay.io/openstack-k8s-operators/neutron-operator-index:${OPENSTACK_K8S_TAG}
NEUTRON_REPO            ?= https://github.com/openstack-k8s-operators/neutron-operator.git
NEUTRON_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
NEUTRON_COMMIT_HASH     ?=
NEUTRONAPI              ?= config/samples/neutron_v1beta1_neutronapi.yaml
NEUTRONAPI_CR           ?= ${OPERATOR_BASE_DIR}/neutron-operator/${NEUTRONAPI}
NEUTRONAPI_DEPL_IMG     ?= unused
# TODO: Do we need interfaces to customize images for the other services ?
NEUTRON_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/neutron-operator/kuttl-test.yaml
NEUTRON_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/neutron-operator/test/kuttl/tests
NEUTRON_KUTTL_NAMESPACE ?= neutron-kuttl-tests

# Controlplane Neutron custom Configuration
OPENSTACK_NEUTRON_CUSTOM_CONF	?=

# BGP
NETWORK_BGP           ?= false
BGP_OVN_ROUTING       ?= false
BGP_ASN               ?= 64999
BGP_PEER_ASN          ?= 64999
BGP_LEAF_1            ?= 100.65.4.1
BGP_LEAF_2            ?= 100.64.4.1
BGP_SOURCE_IP         ?= 172.30.4.2
BGP_SOURCE_IP6       ?= f00d:f00d:f00d:f00d:f00d:f00d:f00d:42
NNCP_BGP_1_INTERFACE  ?= enp7s0
NNCP_BGP_2_INTERFACE  ?= enp8s0
NNCP_BGP_1_IP_ADDRESS ?= 100.65.4.2
NNCP_BGP_2_IP_ADDRESS ?= 100.64.4.2

# Cinder
CINDER_IMG             ?= quay.io/openstack-k8s-operators/cinder-operator-index:${OPENSTACK_K8S_TAG}
CINDER_REPO            ?= https://github.com/openstack-k8s-operators/cinder-operator.git
CINDER_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
CINDER_COMMIT_HASH     ?=
CINDER                 ?= config/samples/cinder_v1beta1_cinder.yaml
CINDER_CR              ?= ${OPERATOR_BASE_DIR}/cinder-operator/${CINDER}
CINDERAPI_DEPL_IMG     ?= unused
CINDERBKP_DEPL_IMG     ?= unused
CINDERSCH_DEPL_IMG     ?= unused
CINDERVOL_DEPL_IMG     ?= unused
CINDER_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/cinder-operator/kuttl-test.yaml
CINDER_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/cinder-operator/test/kuttl/tests
CINDER_KUTTL_NAMESPACE ?= cinder-kuttl-tests

# RabbitMQ
RABBITMQ_IMG            ?= quay.io/openstack-k8s-operators/rabbitmq-cluster-operator-index:${OPENSTACK_K8S_TAG}
RABBITMQ_REPO           ?= https://github.com/openstack-k8s-operators/rabbitmq-cluster-operator.git
RABBITMQ_BRANCH         ?= patches
RABBITMQ_COMMIT_HASH    ?=
RABBITMQ                ?= docs/examples/default-security-context/rabbitmq.yaml
RABBITMQ_CR             ?= ${OPERATOR_BASE_DIR}/rabbitmq-operator/${RABBITMQ}
RABBITMQ_DEPL_IMG       ?= unused

# Ironic
IRONIC_IMG             ?= quay.io/openstack-k8s-operators/ironic-operator-index:${OPENSTACK_K8S_TAG}
IRONIC_REPO            ?= https://github.com/openstack-k8s-operators/ironic-operator.git
IRONIC_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
IRONIC_COMMIT_HASH     ?=
IRONIC                 ?= config/samples/ironic_v1beta1_ironic.yaml
IRONIC_CR              ?= ${OPERATOR_BASE_DIR}/ironic-operator/${IRONIC}
IRONICAPI_DEPL_IMG     ?= unused
IRONICCON_DEPL_IMG     ?= unused
IRONICPXE_DEPL_IMG     ?= unused
IRONICINS_DEPL_IMG     ?= unused
IRONICNAG_DEPL_IMG     ?= unused
IRONIC_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/ironic-operator/kuttl-test.yaml
IRONIC_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/ironic-operator/tests/kuttl/tests
IRONIC_KUTTL_NAMESPACE ?= ironic-kuttl-tests

# Octavia
OCTAVIA_IMG             ?= quay.io/openstack-k8s-operators/octavia-operator-index:${OPENSTACK_K8S_TAG}
OCTAVIA_REPO            ?= https://github.com/openstack-k8s-operators/octavia-operator.git
OCTAVIA_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
OCTAVIA_COMMIT_HASH     ?=
OCTAVIA                 ?= config/samples/octavia_v1beta1_octavia.yaml
OCTAVIA_CR              ?= ${OPERATOR_BASE_DIR}/octavia-operator/${OCTAVIA}
# TODO: Image custom    izations for all Octavia services
OCTAVIA_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/octavia-operator/kuttl-test.yaml
OCTAVIA_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/octavia-operator/tests/kuttl/tests
OCTAVIA_KUTTL_NAMESPACE ?= octavia-kuttl-tests

# Designate
DESIGNATE_IMG             ?= quay.io/openstack-k8s-operators/designate-operator-index:${OPENSTACK_K8S_TAG}
DESIGNATE_REPO            ?= https://github.com/openstack-k8s-operators/designate-operator.git
DESIGNATE_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
DESIGNATE_COMMIT_HASH     ?=
DESIGNATE                 ?= config/samples/designate_v1beta1_designate.yaml
DESIGNATE_CR              ?= ${OPERATOR_BASE_DIR}/designate-operator/${DESIGNATE}
DESIGNATE_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/designate-operator/kuttl-test.yaml
DESIGNATE_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/designate-operator/tests/kuttl/tests
DESIGNATE_KUTTL_NAMESPACE ?= designate-kuttl-tests

# Nova
NOVA_IMG            ?= quay.io/openstack-k8s-operators/nova-operator-index:${OPENSTACK_K8S_TAG}
NOVA_REPO           ?= https://github.com/openstack-k8s-operators/nova-operator.git
NOVA_BRANCH         ?= ${OPENSTACK_K8S_BRANCH}
NOVA_COMMIT_HASH    ?=
# NOTE(gibi): We intentionally not using the default nova sample here
# as that would require two RabbitMQCluster to be deployed which a) is not what
# the make rabbitmq_deploy target does ii) required extra resource in the dev
# environment.
NOVA                ?= config/samples/nova_v1beta1_nova_collapsed_cell.yaml
NOVA_CR             ?= ${OPERATOR_BASE_DIR}/nova-operator/${NOVA}
# TODO: Image customizations for all Nova services

# Horizon
HORIZON_IMG             ?= quay.io/openstack-k8s-operators/horizon-operator-index:${OPENSTACK_K8S_TAG}
HORIZON_REPO            ?= https://github.com/openstack-k8s-operators/horizon-operator.git
HORIZON_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
HORIZON_COMMIT_HASH     ?=
HORIZON                 ?= config/samples/horizon_v1beta1_horizon.yaml
HORIZON_CR              ?= ${OPERATOR_BASE_DIR}/horizon-operator/${HORIZON}
HORIZON_DEPL_IMG        ?= unused
HORIZON_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/horizon-operator/kuttl-test.yaml
HORIZON_KUTTL_NAMESPACE ?= horizon-kuttl-tests
HORIZON_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/horizon-operator/tests/kuttl/tests

# Heat
HEAT_IMG             ?= quay.io/openstack-k8s-operators/heat-operator-index:${OPENSTACK_K8S_TAG}
HEAT_REPO            ?= https://github.com/openstack-k8s-operators/heat-operator.git
HEAT_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
HEAT_COMMIT_HASH     ?=
HEAT                 ?= config/samples/heat_v1beta1_heat.yaml
HEAT_CR              ?= ${OPERATOR_BASE_DIR}/heat-operator/${HEAT}
HEATAPI_DEPL_IMG     ?= unused
HEATCFNAPI_DEPL_IMG  ?= unused
HEATENGINE_DEPL_IMG  ?= unused
HEAT_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/heat-operator/kuttl-test.yaml
HEAT_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/heat-operator/tests/kuttl/tests
HEAT_KUTTL_NAMESPACE ?= heat-kuttl-tests

# AnsibleEE
ANSIBLEEE_IMG        ?= quay.io/openstack-k8s-operators/openstack-ansibleee-operator-index:${OPENSTACK_K8S_TAG}
ANSIBLEEE_REPO       ?= https://github.com/openstack-k8s-operators/openstack-ansibleee-operator
ANSIBLEEE_BRANCH          ?= ${OPENSTACK_K8S_BRANCH}
ANSIBLEE_COMMIT_HASH      ?=
ANSIBLEEE                 ?= config/samples/_v1beta1_ansibleee.yaml
ANSIBLEEE_CR              ?= ${OPERATOR_BASE_DIR}/openstack-ansibleee-operator/${ANSIBLEEE}
ANSIBLEEE_KUTTL_CONF      ?= ${OPERATOR_BASE_DIR}/openstack-ansibleee-operator/kuttl-test.yaml
ANSIBLEEE_KUTTL_DIR       ?= ${OPERATOR_BASE_DIR}/openstack-ansibleee-operator/tests/kuttl/tests
ANSIBLEEE_KUTTL_NAMESPACE ?= ansibleee-kuttl-tests


# Baremetal Operator
BAREMETAL_IMG           ?= quay.io/openstack-k8s-operators/openstack-baremetal-operator-index:${OPENSTACK_K8S_TAG}
BAREMETAL_REPO          ?= https://github.com/openstack-k8s-operators/openstack-baremetal-operator.git
BAREMETAL_BRANCH        ?= ${OPENSTACK_K8S_BRANCH}
BAREMETAL_COMMIT_HASH   ?=
BMH_NAMESPACE           ?= ${NAMESPACE}
BAREMETAL_OS_CONTAINER_IMG ?=

# Dataplane Operator
DATAPLANE_TIMEOUT                                ?= 30m
ifeq ($(NETWORK_BGP), true)
ifeq ($(BGP_OVN_ROUTING), true)
DATAPLANE_KUSTOMIZE_SCENARIO                     ?= bgp_ovn_cluster
else
DATAPLANE_KUSTOMIZE_SCENARIO                     ?= bgp
endif
else
DATAPLANE_KUSTOMIZE_SCENARIO                     ?= preprovisioned
endif
DATAPLANE_ANSIBLE_SECRET                         ?=dataplane-ansible-ssh-private-key-secret
DATAPLANE_ANSIBLE_USER                           ?=
ifeq ($(NETWORK_ISOLATION_USE_DEFAULT_NETWORK), true)
DATAPLANE_COMPUTE_IP                             ?=192.168.122.100
DATAPLANE_NETWORKER_IP							 ?=192.168.122.200
DATAPLANE_SSHD_ALLOWED_RANGES                    ?=['192.168.122.0/24']
DATAPLANE_DEFAULT_GW                             ?= 192.168.122.1
else
DATAPLANE_COMPUTE_IP                             ?=172.16.1.100
DATAPLANE_NETWORKER_IP							 ?=172.16.1.200
DATAPLANE_SSHD_ALLOWED_RANGES                    ?=['172.16.1.0/24']
DATAPLANE_DEFAULT_GW                             ?= 172.16.1.1
endif
DATAPLANE_TOTAL_NODES                            ?=1
DATAPLANE_GROWVOLS_ARGS                          ?=/=8GB /tmp=1GB /home=1GB /var=100%
DATAPLANE_TOTAL_NETWORKER_NODES					 ?=1
DATAPLANE_RUNNER_IMG                             ?=
DATAPLANE_NETWORK_INTERFACE_NAME                 ?=eth0
DATAPLANE_NTP_SERVER                             ?=pool.ntp.org
DATAPLANE_REGISTRY_URL                           ?=quay.io/podified-antelope-centos9
DATAPLANE_CONTAINER_TAG                          ?=current-podified
DATAPLANE_CONTAINER_PREFIX			 ?=openstack
BM_CTLPLANE_INTERFACE                            ?= enp1s0
BM_ROOT_PASSWORD                                 ?=
GENERATE_SSH_KEYS				 ?= true
DATAPLANE_EXTRA_NOVA_CONFIG_FILE                 ?= /dev/null
DATAPLANE_SERVER_ROLE                            ?= compute
DATAPLANE_TLS_ENABLED                            ?= true
DATAPLANE_NOVA_NFS_PATH                          ?=

# Manila
MANILA_IMG              ?= quay.io/openstack-k8s-operators/manila-operator-index:${OPENSTACK_K8S_TAG}
MANILA_REPO             ?= https://github.com/openstack-k8s-operators/manila-operator.git
MANILA_BRANCH           ?= ${OPENSTACK_K8S_BRANCH}
MANILA_COMMIT_HASH      ?=
MANILA                  ?= config/samples/manila_v1beta1_manila.yaml
MANILA_CR               ?= ${OPERATOR_BASE_DIR}/manila-operator/${MANILA}
MANILAAPI_DEPL_IMG      ?= unused
MANILASCH_DEPL_IMG      ?= unused
MANILASHARE_DEPL_IMG    ?= unused
MANILA_KUTTL_CONF       ?= ${OPERATOR_BASE_DIR}/manila-operator/kuttl-test.yaml
MANILA_KUTTL_DIR        ?= ${OPERATOR_BASE_DIR}/manila-operator/test/kuttl/tests
MANILA_KUTTL_NAMESPACE  ?= manila-kuttl-tests

# Ceph
CEPH_IMG       ?= quay.io/ceph/demo:latest-squid
CEPH_REPO      ?= https://github.com/rook/rook.git
CEPH_BRANCH    ?= release-1.15
CEPH_CRDS      ?= ${OPERATOR_BASE_DIR}/rook/deploy/examples/crds.yaml
CEPH_COMMON    ?= ${OPERATOR_BASE_DIR}/rook/deploy/examples/common.yaml
CEPH_OP        ?= ${OPERATOR_BASE_DIR}/rook/deploy/examples/operator-openshift.yaml
CEPH_CR        ?= ${OPERATOR_BASE_DIR}/rook/deploy/examples/cluster-test.yaml
CEPH_CLIENT    ?= ${OPERATOR_BASE_DIR}/rook/deploy/examples/toolbox.yaml

# NNstate
NMSTATE_NAMESPACE      ?= openshift-nmstate
NMSTATE_OPERATOR_GROUP ?= openshift-nmstate-tn6k8
NMSTATE_SUBSCRIPTION   ?= kubernetes-nmstate-operator
INSTALL_NMSTATE        ?= $(NETWORK_ISOLATION) || $(NETWORK_BGP)

# NNCP
INSTALL_NNCP        ?= $(NETWORK_ISOLATION) || $(NETWORK_BGP)
NNCP_NODES          ?=
NNCP_INTERFACE      ?= enp6s0
NNCP_BRIDGE         ?= ospbr
NNCP_TIMEOUT		?= 240s
NNCP_CLEANUP_TIMEOUT	?= 120s
NNCP_CTLPLANE_IP_ADDRESS_SUFFIX     ?=10
ifeq ($(NETWORK_ISOLATION_USE_DEFAULT_NETWORK), true)
NNCP_CTLPLANE_IP_ADDRESS_PREFIX     ?=192.168.122
NNCP_GATEWAY                        ?=192.168.122.1
NNCP_DNS_SERVER                     ?=192.168.122.1
else
NNCP_CTLPLANE_IP_ADDRESS_PREFIX     ?=172.16.1
NNCP_GATEWAY                        ?=172.16.1.1
NNCP_DNS_SERVER                     ?=172.16.1.1
endif
NNCP_CTLPLANE_IPV6_ADDRESS_PREFIX   ?=fd00:aaaa::
NNCP_CTLPLANE_IPV6_ADDRESS_SUFFIX   ?=10
NNCP_GATEWAY_IPV6                   ?=fd00:aaaa::1
NNCP_DNS_SERVER_IPV6                ?=fd00:aaaa::1
NNCP_ADDITIONAL_HOST_ROUTES         ?=
NNCP_RETRIES ?= 5

# MetalLB
ifeq ($(NETWORK_ISOLATION_USE_DEFAULT_NETWORK), true)
METALLB_POOL			 ?=192.168.122.80-192.168.122.90
else
METALLB_POOL			 ?=172.16.1.80-172.16.1.90
endif
METALLB_IPV6_POOL        ?=$(NNCP_CTLPLANE_IPV6_ADDRESS_PREFIX)80-$(NNCP_CTLPLANE_IPV6_ADDRESS_PREFIX)90

# Telemetry
TELEMETRY_IMG                    ?= quay.io/openstack-k8s-operators/telemetry-operator-index:${OPENSTACK_K8S_TAG}
TELEMETRY_REPO                   ?= https://github.com/openstack-k8s-operators/telemetry-operator.git
TELEMETRY_BRANCH                 ?= ${OPENSTACK_K8S_BRANCH}
TELEMETRY_COMMIT_HASH            ?=
TELEMETRY                        ?= config/samples/telemetry_v1beta1_telemetry.yaml
TELEMETRY_CR                     ?= ${OPERATOR_BASE_DIR}/telemetry-operator/${TELEMETRY}
CEILOMETER_CENTRAL_DEPL_IMG      ?= unused
CEILOMETER_NOTIFICATION_DEPL_IMG ?= unused
SG_CORE_DEPL_IMG                 ?= unused
TELEMETRY_KUTTL_BASEDIR   ?= ${OPERATOR_BASE_DIR}/telemetry-operator
TELEMETRY_KUTTL_RELPATH   ?= tests/kuttl/suites
TELEMETRY_KUTTL_CONF      ?= ${TELEMETRY_KUTTL_BASEDIR}/kuttl-test.yaml
TELEMETRY_KUTTL_NAMESPACE ?= telemetry-kuttl-tests

# BMO
BMO_REPO                         ?= https://github.com/metal3-io/baremetal-operator
BMO_BRANCH                       ?= release-0.6
BMO_COMMIT_HASH                  ?=
BMO_PROVISIONING_INTERFACE       ?=
ifeq ($(NETWORK_ISOLATION_USE_DEFAULT_NETWORK), true)
BMO_IRONIC_HOST                  ?= 192.168.122.10
else
BMO_IRONIC_HOST                  ?= 172.16.1.10
endif
BMO_SETUP_ROUTE_REPLACE          ?= true

# Swift
SWIFT_IMG               ?= quay.io/openstack-k8s-operators/swift-operator-index:${OPENSTACK_K8S_TAG}
SWIFT_REPO              ?= https://github.com/openstack-k8s-operators/swift-operator.git
SWIFT_BRANCH            ?= ${OPENSTACK_K8S_BRANCH}
SWIFT_COMMIT_HASH       ?=
SWIFT                   ?= config/samples/swift_v1beta1_swift.yaml
SWIFT_CR                ?= ${OPERATOR_BASE_DIR}/swift-operator/${SWIFT}
SWIFT_KUTTL_CONF        ?= ${OPERATOR_BASE_DIR}/swift-operator/kuttl-test.yaml
SWIFT_KUTTL_DIR         ?= ${OPERATOR_BASE_DIR}/swift-operator/tests/kuttl/tests
SWIFT_KUTTL_NAMESPACE   ?= swift-kuttl-tests

# CertManager
CERTMANAGER_TIMEOUT                  ?= 300s
INSTALL_CERT_MANAGER		     ?= true

# Redis
# REDIS_IMG     ?= (this is unused because this is part of infra operator)
REDIS           ?= config/samples/redis_v1beta1_redis.yaml
REDIS_CR        ?= ${OPERATOR_BASE_DIR}/infra-operator-redis/${REDIS}
REDIS_DEPL_IMG  ?= unused

# target vars for generic operator install info 1: target name , 2: operator name
define vars
${1}: export NAMESPACE=${NAMESPACE}
${1}: export OPERATOR_NAMESPACE=${OPERATOR_NAMESPACE}
${1}: export SECRET=${SECRET}
${1}: export PASSWORD=${PASSWORD}
${1}: export METADATA_SHARED_SECRET=${METADATA_SHARED_SECRET}
${1}: export HEAT_AUTH_ENCRYPTION_KEY=${HEAT_AUTH_ENCRYPTION_KEY}
${1}: export BARBICAN_SIMPLE_CRYPTO_ENCRYPTION_KEY=${BARBICAN_SIMPLE_CRYPTO_ENCRYPTION_KEY}
${1}: export KEYSTONE_FEDERATION_CLIENT_SECRET=${KEYSTONE_FEDERATION_CLIENT_SECRET}
${1}: export KEYSTONE_CRYPTO_PASSPHRASE=${KEYSTONE_CRYPTO_PASSPHRASE}
${1}: export LIBVIRT_SECRET=${LIBVIRT_SECRET}
${1}: export STORAGE_CLASS=${STORAGE_CLASS}
${1}: export OUT=${OUT}
${1}: export CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD}
${1}: export OPERATOR_NAME=${2}
${1}: export OPERATOR_BASE_DIR=${OPERATOR_BASE_DIR}
${1}: export OPERATOR_DIR=${OUT}/${OPERATOR_NAMESPACE}/${2}/op
${1}: export DEPLOY_DIR=${OUT}/${NAMESPACE}/${2}/cr
${1}: export DEPLOY_DIR_EDPM_NETWORKER=${OUT}/${NAMESPACE}/${2}/networker_cr
${1}: export OPENSTACK_REPO=${OPENSTACK_REPO}
${1}: export OPENSTACK_BRANCH=${OPENSTACK_BRANCH}
${1}: export OPENSTACK_COMMIT_HASH=${OPENSTACK_COMMIT_HASH}
${1}: export GIT_CLONE_OPTS=${GIT_CLONE_OPTS}
${1}: export CHECKOUT_FROM_OPENSTACK_REF=${CHECKOUT_FROM_OPENSTACK_REF}
${1}: export TIMEOUT=$(TIMEOUT)
${1}: export OPERATOR_CHANNEL=$(OPERATOR_CHANNEL)
${1}: export OPERATOR_SOURCE=$(OPERATOR_SOURCE)
${1}: export OPERATOR_SOURCE_NAMESPACE=$(OPERATOR_SOURCE_NAMESPACE)
endef

.PHONY: all
all: operator_namespace keystone mariadb placement neutron

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
cleanup: heat_cleanup horizon_cleanup nova_cleanup octavia_cleanup designate_cleanup neutron_cleanup ovn_cleanup ironic_cleanup cinder_cleanup glance_cleanup placement_cleanup swift_cleanup barbican_cleanup keystone_cleanup mariadb_cleanup telemetry_cleanup ansibleee_cleanup rabbitmq_cleanup infra_cleanup manila_cleanup metallb_cleanup ## Delete all operators

.PHONY: deploy_cleanup
deploy_cleanup: manila_deploy_cleanup heat_deploy_cleanup horizon_deploy_cleanup nova_deploy_cleanup redis_deploy_cleanup octavia_deploy_cleanup designate_deploy_cleanup neutron_deploy_cleanup ovn_deploy_cleanup ironic_deploy_cleanup cinder_deploy_cleanup glance_deploy_cleanup placement_deploy_cleanup swift_deploy_cleanup barbican_deploy_cleanup keystone_deploy_cleanup redis_deploy_cleanup mariadb_deploy_cleanup telemetry_deploy_cleanup memcached_deploy_cleanup rabbitmq_deploy_cleanup ## Delete all OpenStack service objects

.PHONY: wait
wait: ## wait for an operator's controller-manager pod to be ready (requires OPERATOR_NAME to be explicitly passed!)
	$(eval $(call vars,$@,$(value OPERATOR_NAME)))
	bash scripts/operator-wait.sh

##@ CRC
.PHONY: crc_storage
crc_storage: namespace ## initialize local storage PVs in CRC vm
	$(eval $(call vars,$@))
	bash scripts/create-pv.sh
	bash scripts/gen-crc-pv-kustomize.sh
	oc apply -f ${OUT}/crc/storage.yaml

.PHONY: crc_storage_cleanup
crc_storage_cleanup: namespace ## cleanup local storage PVs in CRC vm
	$(eval $(call vars,$@))
	bash scripts/cleanup-crc-pv.sh
	if oc get sc ${STORAGE_CLASS}; then oc delete sc ${STORAGE_CLASS}; fi
	bash scripts/delete-pv.sh

.PHONY: crc_storage_release
crc_storage_release: namespace ## make available the "Released" local storage PVs in CRC vm
	$(eval $(call vars,$@))
	bash scripts/release-crc-pv.sh

.PHONY: crc_storage_with_retries
crc_storage_with_retries: ## initialize local storage PVs with retries
	 $(eval $(call vars,$@))
	bash scripts/retry_make_crc_storage.sh $(CRC_STORAGE_RETRIES)

.PHONY: crc_storage_cleanup_with_retries
crc_storage_cleanup_with_retries: ## cleanup local storage PVs with retries
	 $(eval $(call vars,$@))
	bash scripts/retry_make_crc_storage_cleanup.sh $(CRC_STORAGE_RETRIES)

##@ OPERATOR_NAMESPACE
.PHONY: operator_namespace
operator_namespace: export NAMESPACE=${OPERATOR_NAMESPACE}
operator_namespace: ## creates the namespace specified via OPERATOR_NAMESPACE env var (defaults to openstack-operators)
	$(eval $(call vars,$@))
	bash scripts/gen-namespace.sh
	oc apply -f ${OUT}/${OPERATOR_NAMESPACE}/namespace.yaml
	timeout $(TIMEOUT) bash -c "while ! (oc get project.v1.project.openshift.io ${OPERATOR_NAMESPACE}); do sleep 1; done"
ifeq ($(MICROSHIFT) ,0)
	oc project ${OPERATOR_NAMESPACE}
else
	oc config set-context --current --namespace=${OPERATOR_NAMESPACE}
	oc adm policy add-scc-to-user privileged -z default --namespace ${OPERATOR_NAMESPACE}
endif

##@ NAMESPACE
.PHONY: namespace
namespace: ## creates the namespace specified via NAMESPACE env var (defaults to openstack)
	$(eval $(call vars,$@))
	bash scripts/gen-namespace.sh
	oc apply -f ${OUT}/${NAMESPACE}/namespace.yaml
	timeout $(TIMEOUT) bash -c "while ! (oc get project.v1.project.openshift.io ${NAMESPACE}); do sleep 1; done"
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
crc_bmo_setup: export IRONIC_HOST_IP=${BMO_IRONIC_HOST}
crc_bmo_setup: export REPO=${BMO_REPO}
crc_bmo_setup: export BRANCH=${BMO_BRANCH}
crc_bmo_setup: export HASH=${BMO_COMMIT_HASH}
crc_bmo_setup: crc_bmo_cleanup
crc_bmo_setup: $(if $(findstring true,$(INSTALL_CERT_MANAGER)), certmanager)
	$(eval $(call vars,$@))
	mkdir -p ${OPERATOR_BASE_DIR}
	bash -c "CHECKOUT_FROM_OPENSTACK_REF=false OPERATOR_NAME=baremetal scripts/clone-operator-repo.sh"
	pushd ${OPERATOR_BASE_DIR}/baremetal-operator && sed -i -e '$$aIRONIC_IP=${BMO_IRONIC_HOST}' ironic-deployment/default/ironic_bmo_configmap.env config/default/ironic.env && popd
	pushd ${OPERATOR_BASE_DIR}/baremetal-operator && sed -i 's/eth2/${BMO_PROVISIONING_INTERFACE}/g' ironic-deployment/default/ironic_bmo_configmap.env config/default/ironic.env && popd
	pushd ${OPERATOR_BASE_DIR}/baremetal-operator && sed -i 's/ENDPOINT\=http/ENDPOINT\=https/g' ironic-deployment/default/ironic_bmo_configmap.env config/default/ironic.env && popd
	pushd ${OPERATOR_BASE_DIR}/baremetal-operator && sed -i 's/172.22.0.2\:/${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}.10\:/g' ironic-deployment/default/ironic_bmo_configmap.env config/default/ironic.env && popd
	pushd ${OPERATOR_BASE_DIR}/baremetal-operator && sed -i 's/172.22.0.1\:/${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}.11\:/g' ironic-deployment/default/ironic_bmo_configmap.env config/default/ironic.env && popd
	pushd ${OPERATOR_BASE_DIR}/baremetal-operator && sed -i 's/172.22.0./${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}./g' ironic-deployment/default/ironic_bmo_configmap.env config/default/ironic.env && popd
	pushd ${OPERATOR_BASE_DIR}/baremetal-operator && yq 'del(.spec.template.spec.containers[] | select(.name == "ironic-dnsmasq"))' -i ironic-deployment/base/ironic.yaml && popd
	pushd ${OPERATOR_BASE_DIR}/baremetal-operator && make generate manifests && bash tools/deploy.sh -bitm && popd
ifeq ($(BMO_SETUP_ROUTE_REPLACE), true)
	sudo ip route replace 192.168.126.0/24 dev virbr0
endif
	oc patch deployment/baremetal-operator-controller-manager \
	-n baremetal-operator-system --type='json' \
	-p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "quay.io/metal3-io/baremetal-operator:${BMO_BRANCH}"}]'
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

OPENSTACK_PREP_DEPS := validate_marketplace metallb
OPENSTACK_PREP_DEPS += $(if $(findstring true,$(INSTALL_NMSTATE)), nmstate)
OPENSTACK_PREP_DEPS += $(if $(findstring true,$(INSTALL_NNCP)), nncp_with_retries)
OPENSTACK_PREP_DEPS += $(if $(findstring true,$(INSTALL_CERT_MANAGER)), certmanager)
OPENSTACK_PREP_DEPS += $(if $(findstring true,$(NETWORK_ISOLATION)), netattach metallb_config)
OPENSTACK_PREP_DEPS += $(if $(findstring true,$(NETWORK_BGP)), netattach metallb_config)
OPENSTACK_PREP_DEPS += $(if $(findstring true,$(BMO_SETUP)), crc_bmo_setup)

.PHONY: openstack_prep
openstack_prep: export IMAGE=${OPENSTACK_IMG}
openstack_prep: $(OPENSTACK_PREP_DEPS) ## creates the files to install the operator using olm
	$(eval $(call vars,$@,openstack))
	bash scripts/gen-olm.sh

.PHONY: openstack
openstack: openstack_prep operator_namespace ## installs the operator, also runs the prep step. Set OPENSTACK_IMG for custom image.
	$(eval $(call vars,$@,openstack))
	oc apply -f ${OPERATOR_DIR}

.PHONY: openstack_wait
openstack_wait: ## waits openstack CSV to succeed.
	$(eval $(call vars,$@,openstack))
	# call make_openstack if it isn't already
	bash -c '(oc get subscription -n openstack-operators openstack-operator || make openstack) || true'
	timeout $(TIMEOUT) bash -c 'until $$(oc get csv -l operators.coreos.com/openstack-operator.openstack-operators -n ${OPERATOR_NAMESPACE} | grep -q Succeeded); do sleep 1; done'


# creates the new initialization resource for our operators
.PHONY: openstack_init
openstack_init: openstack_wait
	bash -c 'test -f ${OPERATOR_BASE_DIR}/openstack-operator/config/samples/operator_v1beta1_openstack.yaml || make openstack_repo'
	oc apply -f ${OPERATOR_BASE_DIR}/openstack-operator/config/samples/operator_v1beta1_openstack.yaml
	oc wait openstack/openstack -n ${OPERATOR_NAMESPACE} --for condition=Ready --timeout=${TIMEOUT}

.PHONY: openstack_cleanup
openstack_cleanup: operator_namespace## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,openstack))
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}
	if oc get openstack &>/dev/null; then oc delete --ignore-not-found=true openstack/openstack; fi
	oc delete subscription --all=true
	oc delete csv --all=true
	oc delete catalogsource --all=true
	test -d ${OPERATOR_BASE_DIR}/baremetal-operator && make crc_bmo_cleanup || true

.PHONY: openstack_repo
openstack_repo: export REPO=${OPENSTACK_REPO}
openstack_repo: export BRANCH=${OPENSTACK_BRANCH}
openstack_repo: export HASH=${OPENSTACK_COMMIT_HASH}
openstack_repo: ## clones the openstack-operator repo
	$(eval $(call vars,$@,openstack))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash -c "test -d ${OPERATOR_BASE_DIR}/openstack-operator || CHECKOUT_FROM_OPENSTACK_REF=false scripts/clone-operator-repo.sh"

.PHONY: openstack_deploy_prep
openstack_deploy_prep: export KIND=OpenStackControlPlane
openstack_deploy_prep: export OVN_NICMAPPING=${OVNCONTROLLER_NMAP}
openstack_deploy_prep: export NEUTRON_CUSTOM_CONF=${DEPLOY_DIR}/neutron-custom-conf.patch
openstack_deploy_prep: export BRIDGE_NAME=${NNCP_BRIDGE}
openstack_deploy_prep: export CTLPLANE_IP_ADDRESS_PREFIX=${NNCP_CTLPLANE_IPV6_ADDRESS_PREFIX}
ifeq ($(NETWORK_ISOLATION_IPV4), true)
openstack_deploy_prep: export IPV4_ENABLED=true
endif
ifeq ($(NETWORK_ISOLATION_IPV6), true)
openstack_deploy_prep: export IPV6_ENABLED=true
openstack_deploy_prep: export CTLPLANE_IPV6_ADDRESS_PREFIX=${NNCP_CTLPLANE_IPV6_ADDRESS_PREFIX}
openstack_deploy_prep: export CTLPLANE_IPV6_ADDRESS_SUFFIX=${NNCP_CTLPLANE_IPV6_ADDRESS_SUFFIX}
openstack_deploy_prep: export CTLPLANE_IPV6_DNS_SERVER=${NNCP_DNS_SERVER_IPV6}
endif
openstack_deploy_prep: openstack_deploy_cleanup openstack_repo ## prepares the CR to install the service based on the service sample file OPENSTACK
	$(eval $(call vars,$@,openstack))
	cp ${OPENSTACK_CR} ${DEPLOY_DIR}
ifneq (${OPENSTACK_NEUTRON_CUSTOM_CONF},)
	cp ${OPENSTACK_NEUTRON_CUSTOM_CONF} ${NEUTRON_CUSTOM_CONF}
endif
ifeq ($(NETWORK_ISOLATION_USE_DEFAULT_NETWORK), false)
	sed -i 's/192.168.122/${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}/g' ${DEPLOY_DIR}/$(notdir ${OPENSTACK_CR})
endif
	bash scripts/gen-service-kustomize.sh

.PHONY: openstack_deploy
openstack_deploy: input openstack_deploy_prep netconfig_deploy ## installs the service instance using kustomize. Runs prep step in advance. Set OPENSTACK_REPO and OPENSTACK_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,openstack))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: openstack_wait_deploy
openstack_wait_deploy: openstack_deploy ## waits for ctlplane readiness. Runs prep step in advance. Set OPENSTACK_REPO and OPENSTACK_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,openstack))
	oc kustomize ${DEPLOY_DIR} | oc wait --for condition=Ready --timeout=$(TIMEOUT) -f -

.PHONY: openstack_deploy_cleanup
openstack_deploy_cleanup: namespace netconfig_deploy_cleanup ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,openstack))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f - || true
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/openstack-operator ${DEPLOY_DIR}

.PHONY: openstack_update_run
openstack_update_run:
	$(eval $(call vars,$@,openstack))
	bash scripts/openstack-update.sh

OV := $(shell oc get openstackversion -n $(NAMESPACE) -o name)
.PHONY: openstack_patch_version
openstack_patch_version: ## patches the openstackversion target version to the available version, if there is an update available
	$(eval $(call vars,$@,openstack))
	oc wait -n ${NAMESPACE} ${OV} --for=condition=MinorUpdateAvailable --timeout=${TIMEOUT} && \
	oc patch -n ${NAMESPACE} ${OV} --type merge --patch '{"spec": {"targetVersion": "$(shell oc get -n $(NAMESPACE) ${OV} -o yaml | yq .status.availableVersion)"}}'

.PHONY: edpm_deploy_generate_keys
edpm_deploy_generate_keys:
	$(eval $(call vars,$@,dataplane))
	devsetup/scripts/gen-ansibleee-ssh-key.sh
	bash scripts/gen-edpm-nova-migration-ssh-key.sh
ifneq (${EDPM_ROOT_PASSWORD},)
	bash scripts/gen-edpm-bmset-password-secret.sh
endif

.PHONY: edpm_patch_ansible_runner_image
edpm_patch_ansible_runner_image:
	$(eval $(call vars,$@,dataplane))
	oc patch $(shell oc get csv -n ${OPERATOR_NAMESPACE} -o name | grep openstack-operator) \
	-n ${OPERATOR_NAMESPACE} --type='json' \
	-p='[{"op":"replace", "path":"/spec/install/spec/deployments/0/spec/template/spec/containers/1/env/1", "value": {"name": "RELATED_IMAGE_ANSIBLEEE_IMAGE_URL_DEFAULT", "value": "${DATAPLANE_RUNNER_IMG}"}}]'

.PHONY: edpm_deploy_prep
edpm_deploy_prep: export KIND=OpenStackDataPlaneNodeSet
edpm_deploy_prep: export EDPM_ANSIBLE_SECRET=${DATAPLANE_ANSIBLE_SECRET}
edpm_deploy_prep: export EDPM_ANSIBLE_USER=${DATAPLANE_ANSIBLE_USER}
edpm_deploy_prep: export EDPM_NODE_IP=${DATAPLANE_COMPUTE_IP}
edpm_deploy_prep: export EDPM_TOTAL_NODES=${DATAPLANE_TOTAL_NODES}
edpm_deploy_prep: export EDPM_NETWORK_INTERFACE_NAME=${DATAPLANE_NETWORK_INTERFACE_NAME}
edpm_deploy_prep: export CTLPLANE_IP_ADDRESS_PREFIX=${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}
edpm_deploy_prep: export EDPM_SSHD_ALLOWED_RANGES=${DATAPLANE_SSHD_ALLOWED_RANGES}
edpm_deploy_prep: export EDPM_NTP_SERVER=${DATAPLANE_NTP_SERVER}
edpm_deploy_prep: export EDPM_REGISTRY_URL=${DATAPLANE_REGISTRY_URL}
edpm_deploy_prep: export EDPM_CONTAINER_TAG=${DATAPLANE_CONTAINER_TAG}
edpm_deploy_prep: export EDPM_CONTAINER_PREFIX=${DATAPLANE_CONTAINER_PREFIX}
edpm_deploy_prep: export EDPM_EXTRA_NOVA_CONFIG_FILE=${DEPLOY_DIR}/25-nova-extra.conf
edpm_deploy_prep: export EDPM_DEPLOY_DIR=${DEPLOY_DIR}
edpm_deploy_prep: export EDPM_SERVER_ROLE=${DATAPLANE_SERVER_ROLE}
edpm_deploy_prep: export REPO=${OPENSTACK_REPO}
edpm_deploy_prep: export BRANCH=${OPENSTACK_BRANCH}
edpm_deploy_prep: export HASH=${OPENSTACK_COMMIT_HASH}
edpm_deploy_prep: export EDPM_TLS_ENABLED=${DATAPLANE_TLS_ENABLED}
edpm_deploy_prep: export EDPM_NOVA_NFS_PATH=${DATAPLANE_NOVA_NFS_PATH}
ifeq ($(NETWORK_BGP), true)
ifeq ($(BGP_OVN_ROUTING), true)
edpm_deploy_prep: export BGP=ovn
else
edpm_deploy_prep: export BGP=kernel
endif
endif
edpm_deploy_prep: edpm_deploy_cleanup openstack_repo ## prepares the CR to install the data plane
	$(eval $(call vars,$@,dataplane))
	mkdir -p ${DEPLOY_DIR}
	cp ${DATAPLANE_EXTRA_NOVA_CONFIG_FILE} ${EDPM_EXTRA_NOVA_CONFIG_FILE}
	oc apply -f devsetup/edpm/config/ansible-ee-env.yaml
	oc kustomize --load-restrictor LoadRestrictionsNone ${OPERATOR_BASE_DIR}/openstack-operator/config/samples/dataplane/${DATAPLANE_KUSTOMIZE_SCENARIO} > ${DEPLOY_DIR}/dataplane.yaml
	bash scripts/gen-edpm-kustomize.sh
ifeq ($(GENERATE_SSH_KEYS), true)
	make edpm_deploy_generate_keys
endif
	oc apply -f devsetup/edpm/services

.PHONY: edpm_deploy_cleanup
edpm_deploy_cleanup: namespace ## cleans up the edpm instance, Does not affect the operator.
	$(eval $(call vars,$@,dataplane))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/openstack-operator ${DEPLOY_DIR}
	bash scripts/cleanup-edpm_deploy.sh

.PHONY: edpm_deploy
edpm_deploy: input edpm_deploy_prep ## installs the dataplane instance using kustomize. Runs prep step in advance. Set OPENSTACK_REPO and OPENSTACK_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,dataplane))
ifneq ($(DATAPLANE_RUNNER_IMG),)
	make edpm_patch_ansible_runner_image
endif
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: edpm_deploy_baremetal_prep
edpm_deploy_baremetal_prep: export KIND=OpenStackDataPlaneNodeSet
edpm_deploy_baremetal_prep: export EDPM_ANSIBLE_SECRET=${DATAPLANE_ANSIBLE_SECRET}
edpm_deploy_baremetal_prep: export EDPM_ANSIBLE_USER=${DATAPLANE_ANSIBLE_USER}
edpm_deploy_baremetal_prep: export EDPM_BMH_NAMESPACE=${BMH_NAMESPACE}
edpm_deploy_baremetal_prep: export EDPM_OS_CONTAINER_IMG=${BAREMETAL_OS_CONTAINER_IMG}
edpm_deploy_baremetal_prep: export EDPM_PROVISIONING_INTERFACE=${BMO_PROVISIONING_INTERFACE}
edpm_deploy_baremetal_prep: export EDPM_CTLPLANE_INTERFACE=${BM_CTLPLANE_INTERFACE}
edpm_deploy_baremetal_prep: export EDPM_TOTAL_NODES=${DATAPLANE_TOTAL_NODES}
edpm_deploy_baremetal_prep: export EDPM_SSHD_ALLOWED_RANGES=${DATAPLANE_SSHD_ALLOWED_RANGES}
edpm_deploy_baremetal_prep: export EDPM_NTP_SERVER=${DATAPLANE_NTP_SERVER}
edpm_deploy_baremetal_prep: export EDPM_REGISTRY_URL=${DATAPLANE_REGISTRY_URL}
edpm_deploy_baremetal_prep: export EDPM_CONTAINER_TAG=${DATAPLANE_CONTAINER_TAG}
edpm_deploy_baremetal_prep: export EDPM_CONTAINER_PREFIX=${DATAPLANE_CONTAINER_PREFIX}
edpm_deploy_baremetal_prep: export EDPM_GROWVOLS_ARGS=${DATAPLANE_GROWVOLS_ARGS}
edpm_deploy_baremetal_prep: export REPO=${OPENSTACK_REPO}
edpm_deploy_baremetal_prep: export BRANCH=${OPENSTACK_BRANCH}
edpm_deploy_baremetal_prep: export HASH=${OPENSTACK_COMMIT_HASH}
edpm_deploy_baremetal_prep: export DATAPLANE_KUSTOMIZE_SCENARIO=baremetal
edpm_deploy_baremetal_prep: export EDPM_ROOT_PASSWORD=${BM_ROOT_PASSWORD}
edpm_deploy_baremetal_prep: export EDPM_EXTRA_NOVA_CONFIG_FILE=${DEPLOY_DIR}/25-nova-extra.conf
edpm_deploy_baremetal_prep: export EDPM_SERVER_ROLE=compute
edpm_deploy_baremetal_prep: edpm_deploy_cleanup openstack_repo ## prepares the CR to install the data plane
	$(eval $(call vars,$@,dataplane))
	mkdir -p ${DEPLOY_DIR}
	cp ${DATAPLANE_EXTRA_NOVA_CONFIG_FILE} ${EDPM_EXTRA_NOVA_CONFIG_FILE}
	oc apply -f devsetup/edpm/config/ansible-ee-env.yaml
	oc kustomize --load-restrictor LoadRestrictionsNone ${OPERATOR_BASE_DIR}/openstack-operator/config/samples/dataplane/${DATAPLANE_KUSTOMIZE_SCENARIO} > ${DEPLOY_DIR}/dataplane.yaml
	bash scripts/gen-edpm-baremetal-kustomize.sh
ifeq ($(GENERATE_SSH_KEYS), true)
	make edpm_deploy_generate_keys
endif
	oc apply -f devsetup/edpm/services

.PHONY: edpm_deploy_baremetal
edpm_deploy_baremetal: input edpm_deploy_baremetal_prep ## installs the dataplane instance using kustomize. Runs prep step in advance. Set OPENSTACK_REPO and OPENSTACK_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,dataplane))
ifneq ($(DATAPLANE_RUNNER_IMG),)
	make edpm_patch_ansible_runner_image
endif
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: edpm_wait_deploy_baremetal
edpm_wait_deploy_baremetal: edpm_deploy_baremetal ## waits for dataplane readiness. Runs prep step in advance. Set OPENSTACK_REPO and OPENSTACK_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,dataplane))
	oc kustomize ${DEPLOY_DIR} | yq '. | select(.kind == "OpenStackDataPlaneNodeSet"), select(.kind == "OpenStackDataPlaneDeployment")' | oc wait --for condition=Ready --timeout=$(BAREMETAL_TIMEOUT) -f -
	$(MAKE) edpm_nova_discover_hosts

.PHONY: edpm_wait_deploy
edpm_wait_deploy: edpm_deploy ## waits for dataplane readiness. Runs prep step in advance. Set OPENSTACK_REPO and OPENSTACK_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,dataplane))
	oc kustomize ${DEPLOY_DIR} | yq '. | select(.kind == "OpenStackDataPlaneNodeSet"), select(.kind == "OpenStackDataPlaneDeployment")' | oc wait --for condition=Ready --timeout=$(DATAPLANE_TIMEOUT) -f -
	$(MAKE) edpm_nova_discover_hosts

.PHONY: edpm_register_dns
edpm_register_dns: dns_deploy_prep ## register edpm nodes in dns as dnsdata
	$(eval $(call vars,$@,infra))
	oc apply -f ${DEPLOY_DIR}/network_v1beta1_dnsdata.yaml # TODO (mschuppert): register edpm nodes in DNS can be removed after full IPAM integration

.PHONY: edpm_nova_discover_hosts
edpm_nova_discover_hosts: ## trigger manual compute host discovery in nova
	oc rsh nova-cell0-conductor-0 nova-manage cell_v2 discover_hosts --verbose

.PHONY: openstack_crds
openstack_crds: namespace openstack_deploy_prep ## installs all openstack CRDs. Useful for infrastructure dev
	OPENSTACK_BUNDLE_IMG=${OPENSTACK_BUNDLE_IMG} OUT=${OUT} OPENSTACK_CRDS_DIR=${OPENSTACK_CRDS_DIR} OPERATOR_BASE_DIR=${OPERATOR_BASE_DIR} bash scripts/openstack-crds.sh

.PHONY: openstack_crds_cleanup
openstack_crds_cleanup: ## deletes all openstack CRDs. Useful for installing a ga version. expects that all deployments are gone before
	oc delete $$(oc get crd -o name |grep 'openstack\.org')

.PHONY: edpm_deploy_networker_prep
edpm_deploy_networker_prep: export KIND=OpenStackDataPlaneNodeSet
edpm_deploy_networker_prep: export EDPM_ANSIBLE_SECRET=${DATAPLANE_ANSIBLE_SECRET}
edpm_deploy_networker_prep: export EDPM_ANSIBLE_USER=${DATAPLANE_ANSIBLE_USER}
edpm_deploy_networker_prep: export EDPM_NODE_IP=${DATAPLANE_NETWORKER_IP}
edpm_deploy_networker_prep: export EDPM_TOTAL_NODES=${DATAPLANE_TOTAL_NETWORKER_NODES}
edpm_deploy_networker_prep: export OPENSTACK_RUNNER_IMG=${DATAPLANE_RUNNER_IMG}
edpm_deploy_networker_prep: export EDPM_NETWORK_INTERFACE_NAME=${DATAPLANE_NETWORK_INTERFACE_NAME}
edpm_deploy_networker_prep: export CTLPLANE_IP_ADDRESS_PREFIX=${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}
edpm_deploy_networker_prep: export EDPM_SSHD_ALLOWED_RANGES=${DATAPLANE_SSHD_ALLOWED_RANGES}
edpm_deploy_networker_prep: export EDPM_NTP_SERVER=${DATAPLANE_NTP_SERVER}
edpm_deploy_networker_prep: export EDPM_REGISTRY_URL=${DATAPLANE_REGISTRY_URL}
edpm_deploy_networker_prep: export EDPM_CONTAINER_TAG=${DATAPLANE_CONTAINER_TAG}
edpm_deploy_networker_prep: export EDPM_CONTAINER_PREFIX=${DATAPLANE_CONTAINER_PREFIX}
edpm_deploy_networker_prep: export EDPM_DEPLOY_DIR=${DEPLOY_DIR_EDPM_NETWORKER}
edpm_deploy_networker_prep: export EDPM_IP_ADDRESS_OFFSET=200
edpm_deploy_networker_prep: export EDPM_SERVER_ROLE=networker
edpm_deploy_networker_prep: export REPO=${OPENSTACK_REPO}
edpm_deploy_networker_prep: export BRANCH=${OPENSTACK_BRANCH}
edpm_deploy_networker_prep: export HASH=${OPENSTACK_COMMIT_HASH}
edpm_deploy_networker_prep: export DATAPLANE_KUSTOMIZE_SCENARIO=networker
ifeq ($(NETWORK_BGP), true)
ifeq ($(BGP_OVN_ROUTING), true)
edpm_deploy_networker_prep: export BGP=ovn
else
edpm_deploy_networker_prep: export BGP=kernel
endif
endif
edpm_deploy_networker_prep: edpm_deploy_networker_cleanup openstack_repo ## prepares the CR to install the data plane
	echo "START PREP"
	$(eval $(call vars,$@,dataplane))
	mkdir -p ${DEPLOY_DIR_EDPM_NETWORKER}
	oc apply -f devsetup/edpm/config/ansible-ee-env.yaml
	oc kustomize --load-restrictor LoadRestrictionsNone ${OPERATOR_BASE_DIR}/openstack-operator/config/samples/dataplane/${DATAPLANE_KUSTOMIZE_SCENARIO} > ${DEPLOY_DIR_EDPM_NETWORKER}/dataplane.yaml
	bash scripts/gen-edpm-kustomize.sh
ifeq ($(GENERATE_SSH_KEYS), true)
	make edpm_deploy_generate_keys
endif

.PHONY: edpm_deploy_networker_cleanup
edpm_deploy_networker_cleanup: namespace ## cleans up the edpm instance, Does not affect the operator.
	echo "START CLEANUP"
	$(eval $(call vars,$@,dataplane))
	oc kustomize ${DEPLOY_DIR_EDPM_NETWORKER} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/openstack-operator ${DEPLOY_DIR_EDPM_NETWORKER}
	echo "CLEANUP DONE"

.PHONY: edpm_deploy_networker
edpm_deploy_networker: input edpm_deploy_networker_prep ## installs the dataplane instance using kustomize. Runs prep step in advance. Set OPENSTACK_REPO and OPENSTACK_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,dataplane))
	oc apply -f ${OPERATOR_BASE_DIR}/${OPERATOR_NAME}-operator/config/services
ifneq ($(DATAPLANE_RUNNER_IMG),)
	make edpm_patch_ansible_runner_image
endif
	oc kustomize ${DEPLOY_DIR_EDPM_NETWORKER} | oc apply -f -

##@ INFRA
.PHONY: infra_prep
infra_prep: export IMAGE=${INFRA_IMG}
infra_prep: metallb
infra_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,infra))
	bash scripts/gen-olm.sh

.PHONY: infra
infra: operator_namespace infra_prep ## installs the operator, also runs the prep step. Set INFRA_IMG for custom image.
	$(eval $(call vars,$@,infra))
	oc apply -f ${OPERATOR_DIR}

.PHONY: infra_cleanup
infra_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,infra))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

##@ DNS
.PHONY: dns_deploy_prep
dns_deploy_prep: export KIND=DNSMasq
dns_deploy_prep: export IMAGE=${DNS_DEPL_IMG}
dns_deploy_prep: export REPO=${INFRA_REPO}
dns_deploy_prep: export BRANCH=${INFRA_BRANCH}
dns_deploy_prep: export HASH=${INFRA_COMMIT_HASH}
dns_deploy_prep: dns_deploy_cleanup ## prepares the CR to install the service based on the service sample file DNSMASQ and DNSDATA
	$(eval $(call vars,$@,infra))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${DNSMASQ_CR} ${DNSDATA_CR} ${DEPLOY_DIR}
ifeq ($(NETWORK_ISOLATION_USE_DEFAULT_NETWORK), false)
	sed -i 's/192.168.122/${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}/g' ${DEPLOY_DIR}/$(notdir ${DNSMASQ_CR})
	sed -i 's/192.168.122/${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}/g' ${DEPLOY_DIR}/$(notdir ${DNSDATA_CR})
endif
	bash scripts/gen-service-kustomize.sh

.PHONY: dns_deploy
dns_deploy: input dns_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set INFRA_REPO and INFRA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,infra))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: dns_deploy_cleanup
dns_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,infra))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/infra-operator ${DEPLOY_DIR}

##@ NETCONFIG
.PHONY: netconfig_deploy_prep
netconfig_deploy_prep: export KIND=NetConfig
ifeq ($(NETWORK_ISOLATION_IPV4), true)
netconfig_deploy_prep: export IPV4_ENABLED=true
endif
ifeq ($(NETWORK_ISOLATION_IPV6), true)
netconfig_deploy_prep: export IPV6_ENABLED=true
netconfig_deploy_prep: export CTLPLANE_IPV6_ADDRESS_PREFIX=${NNCP_CTLPLANE_IPV6_ADDRESS_PREFIX}
netconfig_deploy_prep: export CTLPLANE_IPV6_GATEWAY=${NNCP_GATEWAY_IPV6}
endif
ifeq ($(NETWORK_BGP), true)
netconfig_deploy_prep: export BGP=enabled
endif
netconfig_deploy_prep: export IMAGE=${NETCONFIG_DEPL_IMG}
netconfig_deploy_prep: export REPO=${INFRA_REPO}
netconfig_deploy_prep: export BRANCH=${INFRA_BRANCH}
netconfig_deploy_prep: export HASH=${INFRA_COMMIT_HASH}
netconfig_deploy_prep: netconfig_deploy_cleanup ## prepares the CR to install the service based on the service sample file DNSMASQ and DNSDATA
	$(eval $(call vars,$@,infra))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${NETCONFIG_CR} ${DEPLOY_DIR}
ifeq ($(NETWORK_ISOLATION_USE_DEFAULT_NETWORK), false)
	sed -i 's/192.168.122/${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}/g' ${DEPLOY_DIR}/$(notdir ${NETCONFIG_CR})
endif
	bash scripts/gen-service-kustomize.sh

.PHONY: netconfig_deploy
netconfig_deploy: input netconfig_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set INFRA_REPO and INFRA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,infra))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: netconfig_deploy_cleanup
netconfig_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,infra))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/infra-operator ${DEPLOY_DIR}

##@ MEMCACHED
.PHONY: memcached_deploy_prep
memcached_deploy_prep: export KIND=Memcached
memcached_deploy_prep: export NAME=memcached
memcached_deploy_prep: export IMAGE=${MEMCACHED_DEPL_IMG}
memcached_deploy_prep: export REPO=${INFRA_REPO}
memcached_deploy_prep: export BRANCH=${INFRA_BRANCH}
memcached_deploy_prep: export HASH=${INFRA_COMMIT_HASH}
memcached_deploy_prep: memcached_deploy_cleanup ## prepares the CR to install the service based on the service sample file MEMCACHED
	$(eval $(call vars,$@,infra))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${MEMCACHED_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: memcached_deploy
memcached_deploy: input memcached_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set INFRA_REPO and INFRA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,infra))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: memcached_deploy_cleanup
memcached_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
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
keystone: operator_namespace keystone_prep ## installs the operator, also runs the prep step. Set KEYSTONE_IMG for custom image.
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
keystone_deploy_prep: export REPO=${KEYSTONE_REPO}
keystone_deploy_prep: export BRANCH=${KEYSTONE_BRANCH}
keystone_deploy_prep: export HASH=${KEYSTONE_COMMIT_HASH}
keystone_deploy_prep: keystone_deploy_cleanup ## prepares the CR to install the service based on the service sample file KEYSTONEAPI
	$(eval $(call vars,$@,keystone))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${KEYSTONEAPI_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: keystone_deploy
keystone_deploy: input keystone_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set KEYSTONE_REPO and KEYSTONE_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,keystone))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: keystone_deploy_cleanup
keystone_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,keystone))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/keystone-operator ${DEPLOY_DIR}
	oc rsh -t $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists keystone;" || true

##@ BARBICAN
.PHONY: barbican_prep
barbican_prep: export IMAGE=${BARBICAN_IMG}
barbican_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,barbican))
	bash scripts/gen-olm.sh

.PHONY: barbican
barbican: namespace barbican_prep ## installs the operator, also runs the prep step. Set BARBICAN_IMG for custom image.
	$(eval $(call vars,$@,barbican))
	oc apply -f ${OPERATOR_DIR}

.PHONY: barbican_cleanup
barbican_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,barbican))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: barbican_deploy_prep
barbican_deploy_prep: export KIND=Barbican
barbican_deploy_prep: export REPO=${BARBICAN_REPO}
barbican_deploy_prep: export BRANCH=${BARBICAN_BRANCH}
barbican_deploy_prep: export HASH=${BARBICAN_COMMIT_HASH}
barbican_deploy_prep: barbican_deploy_cleanup ## prepares the CR to install the service based on the service sample file BARBICAN
	$(eval $(call vars,$@,barbican))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${BARBICAN_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: barbican_deploy
barbican_deploy: input barbican_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set BARBICAN_REPO and BARBICAN_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,barbican))
	bash scripts/operator-deploy-resources.sh

.PHONY: barbican_deploy_validate
barbican_deploy_validate: input namespace ## checks that barbican was properly deployed. Set BARBICAN_KUTTL_DIR to use assert file from custom repo.
	kubectl-kuttl assert -n ${NAMESPACE} ${BARBICAN_KUTTL_DIR}/../common/assert_sample_deployment.yaml --timeout 180

.PHONY: barbican_deploy_cleanup
barbican_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,barbican))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/barbican-operator ${DEPLOY_DIR}
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "drop database barbican;" || true

##@ MARIADB
mariadb_prep: export IMAGE=${MARIADB_IMG}
mariadb_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,mariadb))
	bash scripts/gen-olm.sh

.PHONY: mariadb
mariadb: operator_namespace mariadb_prep ## installs the operator, also runs the prep step. Set MARIADB_IMG for custom image.
	$(eval $(call vars,$@,mariadb))
	oc apply -f ${OPERATOR_DIR}

.PHONY: mariadb_cleanup
mariadb_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,mariadb))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: mariadb_deploy_prep
mariadb_deploy_prep: export KIND=$(patsubst mariadb,MariaDB,$(patsubst galera,Galera,$(DBSERVICE)))
mariadb_deploy_prep: export IMAGE=${MARIADB_DEPL_IMG}
mariadb_deploy_prep: export REPO=${MARIADB_REPO}
mariadb_deploy_prep: export BRANCH=${MARIADB_BRANCH}
mariadb_deploy_prep: export HASH=${MARIADB_COMMIT_HASH}
mariadb_deploy_prep: mariadb_deploy_cleanup ## prepares the CRs files to install the service based on the service sample file MARIADB
	$(eval $(call vars,$@,mariadb))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${MARIADB_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: mariadb_deploy
mariadb_deploy: input mariadb_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set MARIADB_REPO and MARIADB_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,mariadb))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: mariadb_deploy_cleanup
mariadb_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
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
placement: operator_namespace placement_prep ## installs the operator, also runs the prep step. Set PLACEMENT_IMG for custom image.
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
placement_deploy_prep: export REPO=${PLACEMENT_REPO}
placement_deploy_prep: export BRANCH=${PLACEMENT_BRANCH}
placement_deploy_prep: export HASH=${PLACEMENT_COMMIT_HASH}
placement_deploy_prep: placement_deploy_cleanup ## prepares the CR to install the service based on the service sample file PLACEMENTAPI
	$(eval $(call vars,$@,placement))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${PLACEMENTAPI_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: placement_deploy
placement_deploy: input placement_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set PLACEMENT_REPO and PLACEMENT_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,placement))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: placement_deploy_cleanup
placement_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,placement))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/placement-operator ${DEPLOY_DIR}
	oc rsh -t $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists placement;" || true

##@ GLANCE
.PHONY: glance_prep
glance_prep: export IMAGE=${GLANCE_IMG}
glance_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,glance))
	bash scripts/gen-olm.sh

.PHONY: glance
glance: operator_namespace glance_prep ## installs the operator, also runs the prep step. Set GLANCE_IMG for custom image.
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
glance_deploy_prep: export REPO=${GLANCE_REPO}
glance_deploy_prep: export BRANCH=${GLANCE_BRANCH}
glance_deploy_prep: export HASH=${GLANCE_COMMIT_HASH}
glance_deploy_prep: glance_deploy_cleanup ## prepares the CR to install the service based on the service sample file GLANCE
	$(eval $(call vars,$@,glance))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${GLANCE_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: glance_deploy
glance_deploy: input glance_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set GLANCE_REPO and GLANCE_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,glance))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: glance_deploy_cleanup
glance_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,glance))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/glance-operator ${DEPLOY_DIR}
	oc rsh -t $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists glance;" || true

##@ OVN
.PHONY: ovn_prep
ovn_prep: export IMAGE=${OVN_IMG}
ovn_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,ovn))
	bash scripts/gen-olm.sh

.PHONY: ovn
ovn: operator_namespace ovn_prep ## installs the operator, also runs the prep step. Set OVN_IMG for custom image.
	$(eval $(call vars,$@,ovn))
	oc apply -f ${OPERATOR_DIR}

.PHONY: ovn_cleanup
ovn_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,ovn))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: ovn_deploy_prep
ovn_deploy_prep: export KIND=.*
ovn_deploy_prep: export REPO=${OVN_REPO}
ovn_deploy_prep: export BRANCH=${OVN_BRANCH}
ovn_deploy_prep: export HASH=${OVN_COMMIT_HASH}
ovn_deploy_prep: ovn_deploy_cleanup ## prepares the CR to install the service based on the service sample file OVNAPI
	$(eval $(call vars,$@,ovn))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${OVNDBS_CR} ${OVNNORTHD_CR} ${OVNCONTROLLER_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: ovn_deploy
ovn_deploy: ovn_deploy_prep namespace ## installs the service instance using kustomize. Runs prep step in advance. Set OVN_REPO and OVN_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,ovn))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: ovn_deploy_cleanup
ovn_deploy_cleanup:  namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,ovn))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/ovn-operator ${DEPLOY_DIR}

##@ NEUTRON
.PHONY: neutron_prep
neutron_prep: export IMAGE=${NEUTRON_IMG}
neutron_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,neutron))
	bash scripts/gen-olm.sh

.PHONY: neutron
neutron: operator_namespace neutron_prep ## installs the operator, also runs the prep step. Set NEUTRON_IMG for custom image.
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
neutron_deploy_prep: export REPO=${NEUTRON_REPO}
neutron_deploy_prep: export BRANCH=${NEUTRON_BRANCH}
neutron_deploy_prep: export HASH=${NEUTRON_COMMIT_HASH}
neutron_deploy_prep: neutron_deploy_cleanup ## prepares the CR to install the service based on the service sample file NEUTRONAPI
	$(eval $(call vars,$@,neutron))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${NEUTRONAPI_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: neutron_deploy
neutron_deploy: input neutron_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set NEUTRON_REPO and NEUTRON_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,neutron))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: neutron_deploy_cleanup
neutron_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,neutron))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/neutron-operator ${DEPLOY_DIR}
	oc rsh -t $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists neutron;" || true

##@ CINDER
.PHONY: cinder_prep
cinder_prep: export IMAGE=${CINDER_IMG}
cinder_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,cinder))
	bash scripts/gen-olm.sh

.PHONY: cinder
cinder: operator_namespace cinder_prep ## installs the operator, also runs the prep step. Set CINDER_IMG for custom image.
	$(eval $(call vars,$@,cinder))
	oc apply -f ${OPERATOR_DIR}

.PHONY: cinder_cleanup
cinder_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,cinder))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: cinder_deploy_prep
cinder_deploy_prep: export KIND=Cinder
cinder_deploy_prep: export IMAGE=${CINDERAPI_DEPL_IMG},${CINDERBKP_DEPL_IMG},${CINDERSCH_DEPL_IMG},${CINDERVOL_DEPL_IMG}
cinder_deploy_prep: export IMAGE_PATH=cinderAPI/containerImage,cinderBackup/containerImage,cinderScheduler/containerImage,cinderVolumes/volume1/containerImage
cinder_deploy_prep: export REPO=${CINDER_REPO}
cinder_deploy_prep: export BRANCH=${CINDER_BRANCH}
cinder_deploy_prep: export HASH=${CINDER_COMMIT_HASH}
cinder_deploy_prep: cinder_deploy_cleanup ## prepares the CR to install the service based on the service sample file CINDER
	$(eval $(call vars,$@,cinder))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${CINDER_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: cinder_deploy
cinder_deploy: input cinder_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set CINDER_REPO and CINDER_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,cinder))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: cinder_deploy_cleanup
cinder_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,cinder))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/cinder-operator ${DEPLOY_DIR}
	oc rsh -t $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists cinder;" || true

##@ RABBITMQ
.PHONY: rabbitmq_prep
rabbitmq_prep: export IMAGE=${RABBITMQ_IMG}
rabbitmq_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,rabbitmq-cluster))
	bash scripts/gen-olm.sh

.PHONY: rabbitmq
rabbitmq: operator_namespace rabbitmq_prep ## installs the operator, also runs the prep step. Set RABBITMQ_IMG for custom image.
	$(eval $(call vars,$@,rabbitmq-cluster))
	oc apply -f ${OPERATOR_DIR}

.PHONY: rabbitmq_cleanup
rabbitmq_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,rabbitmq-cluster))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: rabbitmq_deploy_prep
rabbitmq_deploy_prep: export KIND=RabbitmqCluster
rabbitmq_deploy_prep: export NAME=rabbitmq
rabbitmq_deploy_prep: export IMAGE=${RABBITMQ_DEPL_IMG}
rabbitmq_deploy_prep: export IMAGE_PATH=image
rabbitmq_deploy_prep: export REPO=${RABBITMQ_REPO}
rabbitmq_deploy_prep: export BRANCH=${RABBITMQ_BRANCH}
rabbitmq_deploy_prep: export HASH=${RABBITMQ_COMMIT_HASH}
rabbitmq_deploy_prep: rabbitmq_deploy_cleanup ## prepares the CR to install the service based on the service sample file RABBITMQ
	$(eval $(call vars,$@,rabbitmq))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash -c "CHECKOUT_FROM_OPENSTACK_REF=false scripts/clone-operator-repo.sh"
	cp ${RABBITMQ_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: rabbitmq_deploy
rabbitmq_deploy: input rabbitmq_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set RABBITMQ_REPO and RABBITMQ_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,rabbitmq))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: rabbitmq_deploy_cleanup
rabbitmq_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,rabbitmq))
	if oc get RabbitmqCluster; then oc delete --ignore-not-found=true RabbitmqCluster --all; fi
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/rabbitmq-operator ${DEPLOY_DIR}

##@ IRONIC
.PHONY: ironic_prep
ironic_prep: export IMAGE=${IRONIC_IMG}
ironic_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,ironic))
	bash scripts/gen-olm.sh

.PHONY: ironic
ironic: operator_namespace ironic_prep ## installs the operator, also runs the prep step. Set IRONIC_IMG for custom image.
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
ironic_deploy_prep: export REPO=${IRONIC_REPO}
ironic_deploy_prep: export BRANCH=${IRONIC_BRANCH}
ironic_deploy_prep: export HASH=${IRONIC_COMMIT_HASH}
ironic_deploy_prep: ironic_deploy_cleanup ## prepares the CR to install the service based on the service sample file IRONIC
	$(eval $(call vars,$@,ironic))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${IRONIC_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: ironic_deploy
ironic_deploy: input ironic_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set IRONIC_REPO and IRONIC_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,ironic))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: ironic_deploy_cleanup
ironic_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,ironic))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/ironic-operator ${DEPLOY_DIR}
	oc rsh -t $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists ironic;" || true
	oc rsh -t $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists ironic_inspector;" || true

##@ OCTAVIA
.PHONY: octavia_prep
octavia_prep: export IMAGE=${OCTAVIA_IMG}
octavia_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,octavia))
	bash scripts/gen-olm.sh

.PHONY: octavia
octavia: operator_namespace octavia_prep ## installs the operator, also runs the prep step. Set OCTAVIA_IMG for custom image.
	$(eval $(call vars,$@,octavia))
	oc apply -f ${OPERATOR_DIR}

.PHONY: octavia_cleanup
octavia_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,octavia))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: octavia_deploy_prep
octavia_deploy_prep: export KIND=Octavia
octavia_deploy_prep: export REPO=${OCTAVIA_REPO}
octavia_deploy_prep: export BRANCH=${OCTAVIA_BRANCH}
octavia_deploy_prep: export HASH=${OCTAVIA_COMMIT_HASH}
octavia_deploy_prep: octavia_deploy_cleanup ## prepares the CR to install the service based on the service sample file OCTAVIA
	$(eval $(call vars,$@,octavia))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${OCTAVIA_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: octavia_deploy
octavia_deploy: input octavia_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set OCTAVIA_REPO and OCTAVIA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,octavia))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: octavia_deploy_cleanup
octavia_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,octavia))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/octavia-operator ${DEPLOY_DIR}
	oc rsh -t $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists octavia;" || true

##@ DESIGNATE
.PHONY: designate_prep
designate_prep: export IMAGE=${DESIGNATE_IMG}
designate_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,designate))
	bash scripts/gen-olm.sh

.PHONY: designate
designate: namespace designate_prep ## installs the operator, also runs the prep step. Set DESIGNATE_IMG for custom image.
	$(eval $(call vars,$@,designate))
	oc apply -f ${OPERATOR_DIR}

.PHONY: designate_cleanup
designate_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,designate))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: designate_deploy_prep
designate_deploy_prep: export KIND=Designate
designate_deploy_prep: export REPO=${DESIGNATE_REPO}
designate_deploy_prep: export BRANCH=${DESIGNATE_BRANCH}
designate_deploy_prep: export HASH=${DESIGNATE_COMMIT_HASH}
designate_deploy_prep: designate_deploy_cleanup ## prepares the CR to install the service based on the service sample file DESIGNATE
	$(eval $(call vars,$@,designate))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${DESIGNATE_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: designate_deploy
designate_deploy: input designate_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set DESIGNATE_REPO and DESIGNATE_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,designate))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: designate_deploy_cleanup
designate_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,designate))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/designate-operator ${DEPLOY_DIR}
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists designate;" || true

##@ NOVA
.PHONY: nova_prep
nova_prep: export IMAGE=${NOVA_IMG}
nova_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,nova))
	bash scripts/gen-olm.sh

.PHONY: nova
nova: operator_namespace nova_prep ## installs the operator, also runs the prep step. Set NOVA_IMG for custom image.
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
nova_deploy_prep: export REPO=${NOVA_REPO}
nova_deploy_prep: export BRANCH=${NOVA_BRANCH}
nova_deploy_prep: export HASH=${NOVA_COMMIT_HASH}
nova_deploy_prep: nova_deploy_cleanup ## prepares the CR to install the service based on the service sample file NOVA
	$(eval $(call vars,$@,nova))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${NOVA_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: nova_deploy
nova_deploy: input nova_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set NOVA_REPO and NOVA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,nova))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: nova_deploy_cleanup
nova_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,nova))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/nova-operator ${DEPLOY_DIR}
	oc rsh $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -ss -e "show databases like 'nova_%';" | xargs -I '{}' oc rsh $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -ss -e "flush tables; drop database if exists {};"

##@ KUTTL tests

.PHONY: mariadb_kuttl_run
mariadb_kuttl_run: ## runs kuttl tests for the mariadb operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${MARIADB_KUTTL_CONF} ${MARIADB_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: mariadb_kuttl
mariadb_kuttl: export NAMESPACE = ${MARIADB_KUTTL_NAMESPACE}
# Set the value of $MARIADB_KUTTL_NAMESPACE if you want to run the keystone
# kuttl tests in a namespace different than the default (mariadb-kuttl-tests)
mariadb_kuttl: input deploy_cleanup mariadb mariadb_deploy_prep ## runs kuttl tests for the mariadb operator. Installs mariadb operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,mariadb))
	make wait
	make mariadb_kuttl_run
	make deploy_cleanup
	make mariadb_cleanup

.PHONY: kuttl_db_prep
kuttl_db_prep: input deploy_cleanup mariadb mariadb_deploy infra memcached_deploy ## installs common DB service(MariaDB and Memcached)

.PHONY: kuttl_db_cleanup
kuttl_db_cleanup: memcached_deploy_cleanup infra_cleanup mariadb_deploy_cleanup mariadb_cleanup input_cleanup

.PHONY: kuttl_common_prep
kuttl_common_prep: validate_marketplace metallb kuttl_db_prep rabbitmq rabbitmq_deploy keystone keystone_deploy ## installs common middleware services and Keystone

.PHONY: kuttl_common_cleanup
kuttl_common_cleanup: keystone_cleanup rabbitmq_cleanup kuttl_db_cleanup metallb_cleanup

.PHONY: keystone_kuttl_run
keystone_kuttl_run: ## runs kuttl tests for the keystone operator, assumes that everything needed for running the test was deployed beforehand.
	KEYSTONE_KUTTL_DIR=${KEYSTONE_KUTTL_DIR} kubectl-kuttl test --config ${KEYSTONE_KUTTL_CONF} ${KEYSTONE_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: keystone_kuttl
keystone_kuttl: export NAMESPACE = ${KEYSTONE_KUTTL_NAMESPACE}
# Set the value of $KEYSTONE_KUTTL_NAMESPACE if you want to run the keystone
# kuttl tests in a namespace different than the default (keystone-kuttl-tests)
keystone_kuttl: kuttl_db_prep rabbitmq rabbitmq_deploy keystone keystone_deploy_prep ## runs kuttl tests for the keystone operator. Installs keystone operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,keystone))
	make wait
	make keystone_kuttl_run
	make deploy_cleanup
	make keystone_cleanup
	make kuttl_db_cleanup
	make rabbitmq_deploy_cleanup
	make rabbitmq_cleanup
	bash scripts/restore-namespace.sh

.PHONY: barbican_kuttl_run
barbican_kuttl_run: ## runs kuttl tests for the barbican operator, assumes that everything needed for running the test was deployed beforehand.
	BARBICAN_KUTTL_DIR=${BARBICAN_KUTTL_DIR} kubectl-kuttl test --config ${BARBICAN_KUTTL_CONF} ${BARBICAN_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: barbican_kuttl
barbican_kuttl: export NAMESPACE = ${BARBICAN_KUTTL_NAMESPACE}
barbican_kuttl: kuttl_common_prep barbican barbican_deploy_prep ## runs kuttl tests for the barbican operator. Installs barbican operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,barbican))
	make wait
	make barbican_kuttl_run
	make deploy_cleanup
	make barbican_cleanup
	make kuttl_common_cleanup
	bash scripts/restore-namespace.sh

.PHONY: placement_kuttl_run
placement_kuttl_run: ## runs kuttl tests for the placement operator, assumes that everything needed for running the test was deployed beforehand.
	PLACEMENT_KUTTL_DIR=${PLACEMENT_KUTTL_DIR} kubectl-kuttl test --config ${PLACEMENT_KUTTL_CONF} ${PLACEMENT_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: placement_kuttl
placement_kuttl: export NAMESPACE = ${PLACEMENT_KUTTL_NAMESPACE}
placement_kuttl: kuttl_common_prep placement placement_deploy_prep ## runs kuttl tests for the placement operator. Installs placement operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,placement))
	make wait
	make placement_kuttl_run
	make deploy_cleanup
	make placement_cleanup
	make kuttl_common_cleanup
	bash scripts/restore-namespace.sh

.PHONY: cinder_kuttl_run
cinder_kuttl_run: ## runs kuttl tests for the cinder operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${CINDER_KUTTL_CONF} ${CINDER_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: cinder_kuttl
cinder_kuttl: export NAMESPACE = ${CINDER_KUTTL_NAMESPACE}
cinder_kuttl: kuttl_common_prep cinder cinder_deploy_prep ## runs kuttl tests for the cinder operator. Installs cinder operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,cinder))
	make wait
	make cinder_kuttl_run
	make deploy_cleanup
	make cinder_cleanup
	make kuttl_common_cleanup
	bash scripts/restore-namespace.sh

.PHONY: neutron_kuttl_run
neutron_kuttl_run: ## runs kuttl tests for the neutron operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${NEUTRON_KUTTL_CONF} ${NEUTRON_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: neutron_kuttl
neutron_kuttl: export NAMESPACE = ${NEUTRON_KUTTL_NAMESPACE}
neutron_kuttl: kuttl_common_prep ovn ovn_deploy neutron neutron_deploy_prep ## runs kuttl tests for the neutron operator. Installs neutron operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,neutron))
	make wait
	make neutron_kuttl_run
	make deploy_cleanup
	make neutron_cleanup
	make ovn_cleanup
	make kuttl_common_cleanup
	bash scripts/restore-namespace.sh

.PHONY: octavia_kuttl_run
octavia_kuttl_run: ## runs kuttl tests for the octavia operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${OCTAVIA_KUTTL_CONF} ${OCTAVIA_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: octavia_kuttl
octavia_kuttl: export NAMESPACE = ${OCTAVIA_KUTTL_NAMESPACE}
octavia_kuttl: kuttl_common_prep ovn ovn_deploy redis_deploy neutron neutron_deploy placement placement_deploy nova nova_deploy glance glance_deploy octavia octavia_deploy_prep ## runs kuttl tests for the octavia operator. Installs octavia operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	make wait OPERATOR_NAME=neutron
	make wait OPERATOR_NAME=placement
	make wait OPERATOR_NAME=nova
	make wait OPERATOR_NAME=glance
	$(eval $(call vars,$@,octavia))
	make wait
	make octavia_kuttl_run
	make deploy_cleanup
	make octavia_cleanup
	make neutron_cleanup
	make placement_cleanup
	make nova_cleanup
	make glance_cleanup
	make ovn_cleanup
	make kuttl_common_cleanup

.PHONY: designate_kuttl
designate_kuttl: export NAMESPACE = ${DESIGNATE_KUTTL_NAMESPACE}
designate_kuttl: kuttl_common_prep ovn ovn_deploy redis_deploy_prep designate designate_deploy_prep ## runs kuttl tests for the designate operator. Installs designate operator and cleans up previous deployments before running the tests and, add cleanup after running the tests.
	$(eval $(call vars,$@,designate))
	make wait
	make designate_kuttl_run
	make deploy_cleanup
	make designate_cleanup
	make ovn_cleanup
	make kuttl_common_cleanup

.PHONY: designate_kuttl_run
designate_kuttl_run: ## runs kuttl tests for the designate operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${DESIGNATE_KUTTL_CONF} ${DESIGNATE_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: ovn_kuttl_run
ovn_kuttl_run: ## runs kuttl tests for the ovn operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${OVN_KUTTL_CONF} ${OVN_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: ovn_kuttl
ovn_kuttl: export NAMESPACE = ${OVN_KUTTL_NAMESPACE}
# Set the value of $OVN_KUTTL_NAMESPACE if you want to run the ovn
# kuttl tests in a namespace different than the default (ovn-kuttl-tests)
ovn_kuttl: input deploy_cleanup infra ovn ovn_deploy_prep ## runs kuttl tests for the ovn operator. Installs ovn operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	make wait OPERATOR_NAME=infra
	$(eval $(call vars,$@,ovn))
	make wait
	make ovn_kuttl_run
	make deploy_cleanup
	make ovn_cleanup
	make infra_cleanup

.PHONY: infra_kuttl_run
infra_kuttl_run: ## runs kuttl tests for the infra operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${INFRA_KUTTL_CONF} ${INFRA_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: infra_kuttl
infra_kuttl: export NAMESPACE = ${INFRA_KUTTL_NAMESPACE}
# Set the value of $INFRA_KUTTL_NAMESPACE if you want to run the infra
# kuttl tests in a namespace different than the default (infra-kuttl-tests)
infra_kuttl: input deploy_cleanup rabbitmq rabbitmq_deploy infra memcached_deploy_prep ## runs kuttl tests for the infra operator. Installs infra operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,infra))
	make wait
	make infra_kuttl_run
	make deploy_cleanup
	make infra_cleanup
	make rabbitmq_cleanup

.PHONY: ironic_kuttl_run
ironic_kuttl_run: ## runs kuttl tests for the ironic operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${IRONIC_KUTTL_CONF} ${IRONIC_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: ironic_kuttl
ironic_kuttl: export NAMESPACE = ${IRONIC_KUTTL_NAMESPACE}
ironic_kuttl: kuttl_common_prep ironic ironic_deploy_prep  ## runs kuttl tests for the ironic operator. Installs ironic operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,ironic))
	make wait
	make ironic_kuttl_run
	make deploy_cleanup
	make ironic_cleanup
	make kuttl_common_cleanup

.PHONY: ironic_kuttl_crc
ironic_kuttl_crc: crc_storage ironic_kuttl

.PHONY: heat_kuttl_run
heat_kuttl_run: ## runs kuttl tests for the heat operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${HEAT_KUTTL_CONF} ${HEAT_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: heat_kuttl
heat_kuttl: export NAMESPACE = ${HEAT_KUTTL_NAMESPACE}
# Set the value of $HEAT_KUTTL_NAMESPACE if you want to run the heat
# kuttl tests in a namespace different than the default (heat-kuttl-tests)
heat_kuttl: kuttl_common_prep heat heat_deploy_prep  ## runs kuttl tests for the heat operator. Installs heat operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,heat))
	make wait
	make heat_kuttl_run
	make deploy_cleanup
	make heat_cleanup
	make kuttl_common_cleanup

.PHONY: heat_kuttl_crc
heat_kuttl_crc: crc_storage heat_kuttl

.PHONY: ansibleee_kuttl_run
ansibleee_kuttl_run: ## runs kuttl tests for the openstack-ansibleee operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${ANSIBLEEE_KUTTL_CONF} ${ANSIBLEEE_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: ansibleee_kuttl_cleanup
ansibleee_kuttl_cleanup:
	$(eval $(call vars,$@,openstack-ansibleee))
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/openstack-ansibleee-operator

.PHONY: ansibleee_kuttl_prep
ansibleee_kuttl_prep: export REPO=${ANSIBLEEE_REPO}
ansibleee_kuttl_prep: export BRANCH=${ANSIBLEEE_BRANCH}
ansibleee_kuttl_prep: export HASH=${ANSIBLEEE_COMMIT_HASH}
ansibleee_kuttl_prep: ansibleee_kuttl_cleanup
	$(eval $(call vars,$@,openstack-ansibleee))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR}
	bash scripts/clone-operator-repo.sh

.PHONY: ansibleee_kuttl
ansibleee_kuttl: export NAMESPACE= ${ANSIBLEEE_KUTTL_NAMESPACE}
ansibleee_kuttl: input ansibleee_kuttl_prep ansibleee ## runs kuttl tests for the openstack-ansibleee operator. Installs openstack-ansibleee operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,openstack-ansibleee))
	make wait
	make ansibleee_kuttl_run
	make ansibleee_cleanup
	bash scripts/restore-namespace.sh

.PHONY: glance_kuttl_run
glance_kuttl_run: ## runs kuttl tests for the glance operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${GLANCE_KUTTL_CONF} ${GLANCE_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: glance_kuttl
glance_kuttl: export NAMESPACE = ${GLANCE_KUTTL_NAMESPACE}
# Set the value of $GLANCE_KUTTL_NAMESPACE if you want to run the glance kuttl tests in a namespace different than the default (glance-kuttl-tests)
# Add swift to get a valid backend we can test
glance_kuttl: kuttl_common_prep swift swift_deploy glance glance_deploy_prep ## runs kuttl tests for the glance operator. Installs glance operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,glance))
	make wait
	make glance_kuttl_run
	make deploy_cleanup
	make glance_cleanup
	make kuttl_common_cleanup

.PHONY: manila_kuttl_run
manila_kuttl_run: ## runs kuttl tests for the manila operator,
	kubectl-kuttl test --config ${MANILA_KUTTL_CONF} ${MANILA_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: manila_kuttl
manila_kuttl: export NAMESPACE = ${MANILA_KUTTL_NAMESPACE}
# Set the value of $MANILA_KUTTL_NAMESPACE if you want to run manila kuttl tests in a namespace different than the default (manila-kuttl-tests)
manila_kuttl: kuttl_common_prep ceph manila manila_deploy_prep ## runs kuttl tests for manila operator. Installs manila operator and cleans up previous deployments before and after running the tests.
	$(eval $(call vars,$@,manila))
	make wait
	make manila_kuttl_run
	make manila_cleanup
	make deploy_cleanup
	make ceph_cleanup
	make kuttl_common_cleanup
	make cleanup

.PHONY: swift_kuttl_run
swift_kuttl_run: ## runs kuttl tests for the swift operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${SWIFT_KUTTL_CONF} ${SWIFT_KUTTL_DIR} --namespace ${NAMESPACE}

.PHONY: swift_kuttl
swift_kuttl: export NAMESPACE = ${SWIFT_KUTTL_NAMESPACE}
swift_kuttl: kuttl_common_prep barbican barbican_deploy swift swift_deploy_prep ## runs kuttl tests for the swift operator. Installs swift operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,swift))
	make wait
	make swift_kuttl_run
	make deploy_cleanup
	make barbican_deploy_cleanup
	make swift_cleanup
	make barbican_cleanup
	make kuttl_common_cleanup

.PHONY: horizon_kuttl_run
horizon_kuttl_run: ## runs kuttl tests for the horizon operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${HORIZON_KUTTL_CONF} ${HORIZON_KUTTL_DIR} --config ${HORIZON_KUTTL_CONF} --namespace ${NAMESPACE}

.PHONY: horizon_kuttl
horizon_kuttl: export NAMESPACE = ${HORIZON_KUTTL_NAMESPACE}
horizon_kuttl: kuttl_common_prep horizon horizon_deploy_prep ## runs kuttl tests for the horizon operator. Installs horizon operator and cleans up previous deployments before running the tests, add cleanup after running the tests.
	$(eval $(call vars,$@,horizon))
	make wait
	make horizon_kuttl_run
	make deploy_cleanup
	make horizon_cleanup
	make kuttl_common_cleanup

.PHONY: openstack_kuttl_run
openstack_kuttl_run: ## runs kuttl tests for the openstack operator, assumes that everything needed for running the test was deployed beforehand.
	set -e; \
	for test_dir in $(shell ls ${OPENSTACK_KUTTL_DIR}); do \
	    oc delete osctlplane --all --namespace ${NAMESPACE}; \
		make crc_storage_cleanup_with_retries; \
		make crc_storage_with_retries; \
		kubectl-kuttl test --config ${OPENSTACK_KUTTL_CONF} ${OPENSTACK_KUTTL_DIR} --test $${test_dir}; \
	done

.PHONY: openstack_kuttl
openstack_kuttl: export NAMESPACE = ${OPENSTACK_KUTTL_NAMESPACE}
openstack_kuttl: input deploy_cleanup openstack openstack_deploy_prep ## runs kuttl tests for the openstack operator. Installs openstack operator and cleans up previous deployments before running the tests, cleans up after running the tests.
	# Wait until OLM installs openstack CRDs
	timeout $(TIMEOUT) bash -c "while ! (oc get crd | grep openstack.org); do sleep 1; done"
	bash -c '(oc get crd openstacks.operator.openstack.org && make openstack_init) || true'
	$(eval $(call vars,$@,ansibleee))
	make wait
	$(eval $(call vars,$@,infra))
	make wait
	$(eval $(call vars,$@,openstack-baremetal))
	make wait
	$(eval $(call vars,$@,openstack))
	make wait
	make openstack_kuttl_run
	make openstack_deploy_cleanup
	make openstack_cleanup

##@ HORIZON
.PHONY: horizon_prep
horizon_prep: export IMAGE=${HORIZON_IMG}
horizon_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,horizon))
	bash scripts/gen-olm.sh

.PHONY: horizon
horizon: operator_namespace horizon_prep ## installs the operator, also runs the prep step. Set HORIZON_IMG for custom image.
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
horizon_deploy_prep: export REPO=${HORIZON_REPO}
horizon_deploy_prep: export BRANCH=${HORIZON_BRANCH}
horizon_deploy_prep: export HASH=${HORIZON_COMMIT_HASH}
horizon_deploy_prep: horizon_deploy_cleanup ## prepares the CR to install the service based on the service sample file HORIZON
	$(eval $(call vars,$@,horizon))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${HORIZON_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: horizon_deploy
horizon_deploy: input horizon_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set HORIZON_REPO and HORIZON_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,horizon))
	make wait
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
heat: operator_namespace heat_prep ## installs the operator, also runs the prep step. Set HEAT_IMG for custom image.
	$(eval $(call vars,$@,heat))
	oc apply -f ${OPERATOR_DIR}

.PHONY: heat_cleanup
heat_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,heat))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: heat_deploy_prep
heat_deploy_prep: export KIND=Heat
heat_deploy_prep: export IMAGE=${HEATAPI_DEPL_IMG},${HEATCFNAPI_DEPL_IMG},${HEATENGINE_DEPL_IMG}
heat_deploy_prep: export IMAGE_PATH=heatAPI/containerImage,heatCfnAPI/containerImage,heatEngine/containerImage
heat_deploy_prep: export REPO=${HEAT_REPO}
heat_deploy_prep: export BRANCH=${HEAT_BRANCH}
heat_deploy_prep: export HASH=${HEAT_COMMIT_HASH}
heat_deploy_prep: heat_deploy_cleanup ## prepares the CR to install the service based on the service sample file HEAT
	$(eval $(call vars,$@,heat))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${HEAT_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: heat_deploy
heat_deploy: input heat_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set HEAT_REPO and HEAT_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,heat))
	make wait
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
ansibleee: operator_namespace ansibleee_prep ## installs the operator, also runs the prep step. Set ansibleee_IMG for custom image.
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

BAREMETAL_DEPS := operator_namespace baremetal_prep
BAREMETAL_DEPS += $(if $(findstring true,$(BMO_SETUP)), crc_bmo_setup)

.PHONY: baremetal
baremetal: $(BAREMETAL_DEPS) ## installs the operator, also runs the prep step. Set BAREMETAL_IMG for custom image.
	$(eval $(call vars,$@,openstack-baremetal))
	oc apply -f ${OPERATOR_DIR}

.PHONY: baremetal_cleanup
baremetal_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,openstack-baremetal))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}
	test -d ${OPERATOR_BASE_DIR}/baremetal-operator && make crc_bmo_cleanup || true

##@ CEPH
.PHONY: ceph_help
ceph_help: export CEPH_IMAGE=${CEPH_IMG}
ceph_help: ## Ceph helper
	$(eval $(call vars,$@,ceph))
	bash scripts/gen-ceph-kustomize.sh "help" "full"

.PHONY: ceph
ceph: export CEPH_IMAGE=${CEPH_IMG}
ceph: namespace input ## deploy the Ceph Pod
	$(eval $(call vars,$@,ceph))
	bash scripts/gen-ceph-kustomize.sh "build"
	bash scripts/operator-deploy-resources.sh
	bash scripts/gen-ceph-kustomize.sh "isready"
	bash scripts/gen-ceph-kustomize.sh "config"
	bash scripts/gen-ceph-kustomize.sh "cephfs"
	bash scripts/gen-ceph-kustomize.sh "pools"
	bash scripts/gen-ceph-kustomize.sh "secret"
	bash scripts/gen-ceph-kustomize.sh "post"

.PHONY: ceph_cleanup
ceph_cleanup: ## deletes the ceph pod
	$(eval $(call vars,$@,ceph))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${DEPLOY_DIR}

##@ ROOK

.PHONY: rook_prep
rook_prep: ### deploy rook operator
	$(eval $(call vars,$@,ceph))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	pushd ${OPERATOR_BASE_DIR} && git clone -b ${CEPH_BRANCH} ${CEPH_REPO} && popd
	cp ${CEPH_CR} ${DEPLOY_DIR}
	cp ${CEPH_CLIENT} ${DEPLOY_DIR}

.PHONY: rook
rook: namespace rook_prep ## installs the CRDs and the operator, also runs the prep step.
	$(eval $(call vars,$@,ceph))
	# Create the Ceph related CRDs
	oc apply -f ${CEPH_CRDS}
	# Apply roles, sa, scc and common resources
	oc apply -f ${CEPH_COMMON}
	# Run the rook operator
	oc apply -f ${CEPH_OP}
	## Do not deploy NFS CEPH-CSI
	oc -n rook-ceph patch configmap rook-ceph-operator-config --type='merge' -p '{"data": { "ROOK_CSI_ENABLE_CEPHFS": "false" }}'

.PHONY: rook_deploy_prep
rook_deploy_prep: export IMAGE=${CEPH_IMG}
rook_deploy_prep: # ceph_deploy_cleanup ## prepares the CR to install the service based on the service sample
	$(eval $(call vars,$@,ceph))
	# Patch the rook-ceph scc to allow using hostnetworking: this simulates an
	# external ceph cluster
	oc patch scc rook-ceph --type='merge' -p '{ "allowHostNetwork": true, "allowHostPID": true, "allowHostPorts": true}'
	bash scripts/gen-rook-kustomize.sh

.PHONY: rook_deploy
rook_deploy: rook_deploy_prep ## installs the service instance using kustomize.
	$(eval $(call vars,$@,ceph))
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: rook_crc_disk
rook_crc_disk: ## Create a disk and attach to CRC / SNO VM
	$(eval $(call vars,$@,ceph))
	bash scripts/disk-setup.sh

.PHONY: rook_cleanup
rook_cleanup: ## deletes rook resources
	$(eval $(call vars,$@,ceph))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${DEPLOY_DIR}
	# Remove the operator
	oc delete --ignore-not-found=true -f ${CEPH_OP}
	# Delete the rook/ceph related resources
	rm -Rf ${OPERATOR_BASE_DIR}/rook ${DEPLOY_DIR}

##@ LVMS
.PHONY: lvms
lvms: ## deploy lvms operator
	$(eval $(call vars,$@,lvms))
	bash scripts/gen-lvms-kustomize.sh

lvms_deploy: export LVMS_CLUSTER_CR=${LVMS_CR}
lvms_deploy: ## deploy lvms cluster
	$(eval $(call vars,$@,lvms))
	bash scripts/gen-lvms-kustomize.sh

lvms_cleanup: ## delete the lvms operator
	$(eval $(call vars,$@,lvms))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -

lvms_deploy_cleanup: ## delete the lvms cluster
	$(eval $(call vars,$@,lvms))
	oc delete -f ${DEPLOY_DIR}/lvms_cluster.yaml

##@ NMSTATE
.PHONY: nmstate
nmstate: export NAMESPACE=${NMSTATE_NAMESPACE}
nmstate: export OPERATOR_GROUP=${NMSTATE_OPERATOR_GROUP}
nmstate: export SUBSCRIPTION=${NMSTATE_SUBSCRIPTION}
nmstate: ## installs nmstate operator in the openshift-nmstate namespace
	$(eval $(call vars,$@,nmstate))
	bash scripts/gen-namespace.sh
	oc apply -f ${OUT}/${NAMESPACE}/namespace.yaml
	timeout $(TIMEOUT) bash -c "while ! (oc get project.v1.project.openshift.io ${NAMESPACE}); do sleep 1; done"
ifeq ($(OKD), true)
	bash scripts/gen-olm-nmstate-okd.sh
	oc apply -f ${OPERATOR_DIR}
	timeout ${TIMEOUT} bash -c "while ! (oc get deployments/nmstate-operator -n ${NAMESPACE}); do sleep 10; done"
	oc wait deployments/nmstate-operator -n ${NAMESPACE} --for condition=Available --timeout=${TIMEOUT}
	oc apply -f ${DEPLOY_DIR}
	sleep 30
else
	bash scripts/gen-olm-nmstate.sh
	oc apply -f ${OPERATOR_DIR}
	timeout ${TIMEOUT} bash -c "while ! (oc get deployments/nmstate-operator -n ${NAMESPACE}); do sleep 10; done"
	oc wait deployments/nmstate-operator -n ${NAMESPACE} --for condition=Available --timeout=${TIMEOUT}
	oc apply -f ${DEPLOY_DIR}
	timeout ${TIMEOUT} bash -c "while ! (oc get pod --no-headers=true -l component=kubernetes-nmstate-handler -n ${NAMESPACE}| grep nmstate-handler); do sleep 10; done"
	oc wait pod -n ${NAMESPACE} -l component=kubernetes-nmstate-handler --for condition=Ready --timeout=$(TIMEOUT)
	timeout ${TIMEOUT} bash -c "while ! (oc get deployments/nmstate-webhook -n ${NAMESPACE}); do sleep 10; done"
	oc wait deployments/nmstate-webhook -n ${NAMESPACE} --for condition=Available --timeout=${TIMEOUT}
endif

.PHONY: nncp_with_retries
nncp_with_retries: ## Deploy NNCP with retries
	 $(eval $(call vars,$@))
	bash scripts/retry_make_nncp.sh $(NNCP_RETRIES)


.PHONY: nncp
nncp: export INTERFACE=${NNCP_INTERFACE}
nncp: export BRIDGE_NAME=${NNCP_BRIDGE}
nncp: export INTERNALAPI_PREFIX=${NETWORK_INTERNALAPI_ADDRESS_PREFIX}
nncp: export NNCP_INTERNALAPI_HOST_ROUTES=${INTERNALAPI_HOST_ROUTES}
nncp: export STORAGE_PREFIX=${NETWORK_STORAGE_ADDRESS_PREFIX}
nncp: export NNCP_STORAGE_HOST_ROUTES=${STORAGE_HOST_ROUTES}
nncp: export STORAGEMGMT_PREFIX=${NETWORK_STORAGEMGMT_ADDRESS_PREFIX}
nncp: export NNCP_STORAGEMGMT_HOST_ROUTES=${STORAGEMGMT_HOST_ROUTES}
nncp: export TENANT_PREFIX=${NETWORK_TENANT_ADDRESS_PREFIX}
nncp: export NNCP_TENANT_HOST_ROUTES=${TENANT_HOST_ROUTES}
nncp: export DESIGNATE_PREFIX=${NETWORK_DESIGNATE_ADDRESS_PREFIX}
ifeq ($(NETWORK_BGP), true)
nncp: export BGP=enabled
nncp: export INTERFACE_BGP_1=${NNCP_BGP_1_INTERFACE}
nncp: export INTERFACE_BGP_2=${NNCP_BGP_2_INTERFACE}
nncp: export BGP_1_IP_ADDRESS=${NNCP_BGP_1_IP_ADDRESS}
nncp: export BGP_2_IP_ADDRESS=${NNCP_BGP_2_IP_ADDRESS}
nncp: export LO_IP_ADDRESS=${BGP_SOURCE_IP}
nncp: export LO_IP6_ADDRESS=${BGP_SOURCE_IP6}
endif
ifeq ($(NETWORK_ISOLATION_IPV6), true)
nncp: export IPV6_ENABLED=true
nncp: export CTLPLANE_IPV6_ADDRESS_PREFIX=${NNCP_CTLPLANE_IPV6_ADDRESS_PREFIX}
nncp: export CTLPLANE_IPV6_ADDRESS_SUFFIX=${NNCP_CTLPLANE_IPV6_ADDRESS_SUFFIX}
nncp: export DNS_SERVER_IPV6=${NNCP_DNS_SERVER_IPV6}
endif
ifeq ($(NETWORK_ISOLATION_IPV4), true)
nncp: export IPV4_ENABLED=true
nncp: export CTLPLANE_IP_ADDRESS_PREFIX=${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}
nncp: export CTLPLANE_IP_ADDRESS_SUFFIX=${NNCP_CTLPLANE_IP_ADDRESS_SUFFIX}
nncp: export DNS_SERVER=${NNCP_DNS_SERVER}
endif
nncp: export INTERFACE_MTU=${NETWORK_MTU}
nncp: export VLAN_START=${NETWORK_VLAN_START}
nncp: export VLAN_STEP=${NETWORK_VLAN_STEP}
nncp: export STORAGE_MACVLAN=${NETWORK_STORAGE_MACVLAN}
## NOTE(ldenny): When applying the nncp resource the OCP API can momentarly drop, below retry is added to aviod checking status while API is down and failing.
nncp: ## installs the nncp resources to configure the interface connected to the edpm node, right now only single nic vlan. Interface referenced via NNCP_INTERFACE
	$(eval $(call vars,$@,nncp))
ifeq ($(NNCP_NODES),)
	WORKERS='$(shell oc get nodes -l node-role.kubernetes.io/worker -o jsonpath="{.items[*].metadata.name}")' \
	bash scripts/gen-nncp.sh
else
	WORKERS=${NNCP_NODES} bash scripts/gen-nncp.sh
endif
	oc apply -f ${DEPLOY_DIR}/
	timeout ${NNCP_TIMEOUT} bash -c "while ! (oc wait nncp -l osp/interface=${NNCP_INTERFACE} --for jsonpath='{.status.conditions[0].reason}'=SuccessfullyConfigured); do sleep 10; done"


.PHONY: nncp_cleanup
nncp_cleanup: export INTERFACE=${NNCP_INTERFACE}
nncp_cleanup: ## unconfigured nncp configuration on worker node and deletes the nncp resource
	$(eval $(call vars,$@,nncp))
	sed -i 's/state: up/state: absent/' ${DEPLOY_DIR}/*_nncp.yaml
	oc apply -f ${DEPLOY_DIR}/
	oc wait nncp -l osp/interface=${NNCP_INTERFACE} --for condition=available --timeout=$(NNCP_CLEANUP_TIMEOUT)
	oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/
	${CLEANUP_DIR_CMD} ${DEPLOY_DIR}

.PHONY: netattach
netattach: export INTERFACE=${NNCP_INTERFACE}
netattach: export BRIDGE_NAME=${NNCP_BRIDGE}
ifeq ($(NETWORK_BGP), true)
netattach: export INTERFACE_BGP_1=${NNCP_BGP_1_INTERFACE}
netattach: export INTERFACE_BGP_2=${NNCP_BGP_2_INTERFACE}
endif
ifeq ($(NETWORK_ISOLATION_IPV4), true)
netattach: export IPV4_ENABLED=true
netattach: export CTLPLANE_IP_ADDRESS_PREFIX=${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}
netattach: export CTLPLANE_IP_ADDRESS_SUFFIX=${NNCP_CTLPLANE_IP_ADDRESS_SUFFIX}
endif
ifeq ($(NETWORK_ISOLATION_IPV6), true)
netattach: export IPV6_ENABLED=true
netattach: export CTLPLANE_IPV6_ADDRESS_PREFIX=${NNCP_CTLPLANE_IPV6_ADDRESS_PREFIX}
netattach: export CTLPLANE_IPV6_ADDRESS_SUFFIX=${NNCP_CTLPLANE_IPV6_ADDRESS_SUFFIX}
endif
netattach: export INTERNALAPI_PREFIX=${NETWORK_INTERNALAPI_ADDRESS_PREFIX}
netattach: export STORAGE_PREFIX=${NETWORK_STORAGE_ADDRESS_PREFIX}
netattach: export STORAGEMGMT_PREFIX=${NETWORK_STORAGEMGMT_ADDRESS_PREFIX}
netattach: export TENANT_PREFIX=${NETWORK_TENANT_ADDRESS_PREFIX}
netattach: export DESIGNATE_PREFIX=${NETWORK_DESIGNATE_ADDRESS_PREFIX}
netattach: export VLAN_START=${NETWORK_VLAN_START}
netattach: export VLAN_STEP=${NETWORK_VLAN_STEP}
netattach: export CTLPLANE_IP_ADDRESS_PREFIX=${NNCP_CTLPLANE_IP_ADDRESS_PREFIX}
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
metallb: ## installs metallb operator in the metallb-system namespace
	$(eval $(call vars,$@,metallb))
	bash scripts/gen-namespace.sh
	oc apply -f ${OUT}/${NAMESPACE}/namespace.yaml
	timeout $(TIMEOUT) bash -c "while ! (oc get project.v1.project.openshift.io ${NAMESPACE}); do sleep 1; done"
ifeq ($(OKD), true)
	bash scripts/gen-operatorshub-catalog.sh
	oc apply -f ${OPERATOR_DIR}/operatorshub-catalog/
	timeout ${TIMEOUT} bash -c "while ! (oc get packagemanifests metallb-operator --no-headers=true | grep metallb-operator); do sleep 10; done"
	bash scripts/gen-olm-metallb-okd.sh
	oc apply -f ${OPERATOR_DIR}
	timeout ${TIMEOUT} bash -c "while ! (oc get deployment metallb-operator-controller-manager --no-headers=true -n ${NAMESPACE}| grep metallb-operator-controller-manager); do sleep 10; done"
	oc apply -f ${OPERATOR_DIR}/patches
	oc wait -n ${NAMESPACE} --for=condition=Available deployment/metallb-operator-controller-manager --timeout=${TIMEOUT}
	# we ensure the outdated replica is terminated (i.e only one replica available)
	timeout ${TIMEOUT} bash -c "while ! (oc get pod --no-headers=true -l control-plane=controller-manager -n ${NAMESPACE}| grep metallb-operator-controller | wc -l | grep -q -e 1); do sleep 10; done"
else
	bash scripts/gen-olm-metallb.sh
	oc apply -f ${OPERATOR_DIR}
endif
	timeout ${TIMEOUT} bash -c "while ! (oc get pod --no-headers=true -l control-plane=controller-manager -n ${NAMESPACE}| grep metallb-operator-controller); do sleep 10; done"
	oc wait pod -n ${NAMESPACE} --for condition=Ready -l control-plane=controller-manager --timeout=$(TIMEOUT)
	timeout ${TIMEOUT} bash -c "while ! (oc get pod --no-headers=true -l component=webhook-server -n ${NAMESPACE}| grep metallb-operator-webhook); do sleep 10; done"
	oc wait pod -n ${NAMESPACE} --for condition=Ready -l component=webhook-server --timeout=$(TIMEOUT)
	oc apply -f ${DEPLOY_DIR}/deploy_operator.yaml
	timeout ${TIMEOUT} bash -c "while ! (oc get pod --no-headers=true -l component=speaker -n ${NAMESPACE} | grep speaker); do sleep 10; done"
	oc wait pod -n ${NAMESPACE} -l component=speaker --for condition=Ready --timeout=$(TIMEOUT)

.PHONY: metallb_config
metallb_config: export NAMESPACE=metallb-system
metallb_config: export CTLPLANE_METALLB_POOL=${METALLB_POOL}
metallb_config: export CTLPLANE_METALLB_IPV6_POOL=${METALLB_IPV6_POOL}
metallb_config: export INTERNALAPI_PREFIX=${NETWORK_INTERNALAPI_ADDRESS_PREFIX}
metallb_config: export STORAGE_PREFIX=${NETWORK_STORAGE_ADDRESS_PREFIX}
metallb_config: export STORAGEMGMT_PREFIX=${NETWORK_STORAGEMGMT_ADDRESS_PREFIX}
metallb_config: export TENANT_PREFIX=${NETWORK_TENANT_ADDRESS_PREFIX}
metallb_config: export DESIGNATE_PREFIX=${NETWORK_DESIGNATE_ADDRESS_PREFIX}
ifeq ($(NETWORK_ISOLATION_IPV4), true)
metallb_config: export IPV4_ENABLED=true
endif
ifeq ($(NETWORK_ISOLATION_IPV6), true)
metallb_config: export IPV6_ENABLED=true
endif
metallb_config: export INTERFACE=${NNCP_INTERFACE}
metallb_config: export BRIDGE_NAME=${NNCP_BRIDGE}
metallb_config: export ASN=${BGP_ASN}
metallb_config: export PEER_ASN=${BGP_PEER_ASN}
metallb_config: export LEAF_1=${BGP_LEAF_1}
metallb_config: export LEAF_2=${BGP_LEAF_2}
metallb_config: export SOURCE_IP=${BGP_SOURCE_IP}
metallb_config: export SOURCE_IP6=${BGP_SOURCE_IP6}
metallb_config: metallb_config_cleanup ## creates the IPAddressPools and l2advertisement resources
	$(eval $(call vars,$@,metallb))
	bash scripts/gen-metallb-config.sh
	oc apply -f ${DEPLOY_DIR}/ipaddresspools.yaml
	oc apply -f ${DEPLOY_DIR}/l2advertisement.yaml
ifeq ($(NETWORK_BGP), true)
	oc apply -f ${DEPLOY_DIR}/bgppeers.yaml
	oc apply -f ${DEPLOY_DIR}/bgpadvertisement.yaml
	oc apply -f ${DEPLOY_DIR}/bgpextras.yaml
endif

.PHONY: metallb_config_cleanup
metallb_config_cleanup: export NAMESPACE=metallb-system
metallb_config_cleanup: ## deletes the IPAddressPools and l2advertisement resources
	$(eval $(call vars,$@,metallb))
	-oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/ipaddresspools.yaml
	-oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/l2advertisement.yaml
	-oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/bgppeers.yaml
	-oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/bgpadvertisement.yaml
	-oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/bgpextras.yaml
	${CLEANUP_DIR_CMD} ${DEPLOY_DIR}/ipaddresspools.yaml ${DEPLOY_DIR}/l2advertisement.yaml ${DEPLOY_DIR}/bgppeers.yaml ${DEPLOY_DIR}/bgpadvertisement.yaml ${DEPLOY_DIR}/bgpextras.yaml

.PHONY: metallb_cleanup
metallb_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,metallb))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

##@ MANILA
.PHONY: manila_prep
manila_prep: export IMAGE=${MANILA_IMG}
manila_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,manila))
	bash scripts/gen-olm.sh

.PHONY: manila
manila: operator_namespace manila_prep ## installs the operator, also runs the prep step. Set MANILA_IMG for custom image.
	$(eval $(call vars,$@,manila))
	oc apply -f ${OPERATOR_DIR}

.PHONY: manila_cleanup
manila_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,manila))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: manila_deploy_prep
manila_deploy_prep: export KIND=Manila
manila_deploy_prep: export IMAGE=${MANILAAPI_DEPL_IMG},${MANILASCH_DEPL_IMG},${MANILASHARE_DEPL_IMG}
manila_deploy_prep: export IMAGE_PATH=manilaAPI/containerImage,manilaScheduler/containerImage,manilaShares/share1/containerImage
manila_deploy_prep: export REPO=${MANILA_REPO}
manila_deploy_prep: export BRANCH=${MANILA_BRANCH}
manila_deploy_prep: export HASH=${MANILA_COMMIT_HASH}
manila_deploy_prep: manila_deploy_cleanup ## prepares the CR to install the service based on the service sample file MANILA
	$(eval $(call vars,$@,manila))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${MANILA_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: manila_deploy
manila_deploy: input manila_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set CINDER_REPO and CINDER_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,manila))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: manila_deploy_cleanup
manila_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,manila))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/manila-operator ${DEPLOY_DIR}
	oc rsh -t mariadb-openstack mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists manila;" || true

##@ TELEMETRY
.PHONY: telemetry_prep
telemetry_prep: export IMAGE=${TELEMETRY_IMG}
telemetry_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,telemetry))
	bash scripts/gen-olm.sh

.PHONY: telemetry
telemetry: operator_namespace telemetry_prep ## installs the operator, also runs the prep step. Set TELEMETRY_IMG for custom image.
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
telemetry_deploy_prep: export REPO=${TELEMETRY_REPO}
telemetry_deploy_prep: export BRANCH=${TELEMETRY_BRANCH}
telemetry_deploy_prep: export HASH=${TELEMETRY_COMMIT_HASH}
telemetry_deploy_prep: telemetry_deploy_cleanup ## prepares the CR to install the service based on the service sample file TELEMETRY
	$(eval $(call vars,$@,telemetry))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${TELEMETRY_CR} ${DEPLOY_DIR}
	bash scripts/gen-service-kustomize.sh

.PHONY: telemetry_deploy
telemetry_deploy: input telemetry_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set TELEMETRY_REPO and TELEMETRY_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,telemetry))
	make wait
	bash scripts/operator-deploy-resources.sh

.PHONY: telemetry_deploy_cleanup
telemetry_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,telemetry))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/telemetry-operator ${DEPLOY_DIR}
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/ceilometer-operator ${DEPLOY_DIR}
	oc rsh -t $(DBSERVICE_CONTAINER) mysql -u root --password=${PASSWORD} -e "flush tables; drop database if exists aodh;" || true

.PHONY: telemetry_kuttl_run
telemetry_kuttl_run: ## runs kuttl tests for the telemetry operator, assumes that everything needed for running the test was deployed beforehand.
	kubectl-kuttl test --config ${TELEMETRY_KUTTL_CONF} --namespace ${NAMESPACE}

.PHONY: telemetry_kuttl
telemetry_kuttl: export NAMESPACE = ${TELEMETRY_KUTTL_NAMESPACE}
# Set the value of $TELEMETRY_KUTTL_NAMESPACE if you want to run the telemetry
# kuttl tests in a namespace different than the default (telemetry-kuttl-tests)
telemetry_kuttl: kuttl_common_prep heat heat_deploy telemetry telemetry_deploy_prep
	$(eval $(call vars,$@,telemetry))
	sed -i "s#- ${TELEMETRY_KUTTL_RELPATH}#- ${TELEMETRY_KUTTL_BASEDIR}/${TELEMETRY_KUTTL_RELPATH}#g" ${TELEMETRY_KUTTL_CONF}
	make wait
	make telemetry_kuttl_run
	make deploy_cleanup
	make telemetry_cleanup
	make heat_cleanup
	make kuttl_common_cleanup
	bash scripts/restore-namespace.sh

##@ SWIFT
.PHONY: swift_prep
swift_prep: export IMAGE=${SWIFT_IMG}
swift_prep: ## creates the files to install the operator using olm
	$(eval $(call vars,$@,swift))
	bash scripts/gen-olm.sh

.PHONY: swift
swift: operator_namespace swift_prep ## installs the operator, also runs the prep step. Set SWIFT_IMG for custom image.
	$(eval $(call vars,$@,swift))
	oc apply -f ${OPERATOR_DIR}

.PHONY: swift_cleanup
swift_cleanup: ## deletes the operator, but does not cleanup the service resources
	$(eval $(call vars,$@,swift))
	bash scripts/operator-cleanup.sh
	${CLEANUP_DIR_CMD} ${OPERATOR_DIR}

.PHONY: swift_deploy_prep
swift_deploy_prep: export KIND=Swift
swift_deploy_prep: export IMAGE=unused
swift_deploy_prep: export REPO=${SWIFT_REPO}
swift_deploy_prep: export BRANCH=${SWIFT_BRANCH}
swift_deploy_prep: export HASH=${SWIFT_COMMIT_HASH}
swift_deploy_prep: swift_deploy_cleanup ## prepares the CR to install the service based on the service sample file SWIFTAPI
	$(eval $(call vars,$@,swift))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${DEPLOY_DIR}
	bash scripts/clone-operator-repo.sh
	cp ${SWIFT_CR} ${DEPLOY_DIR}

	bash scripts/gen-service-kustomize.sh

.PHONY: swift_deploy
swift_deploy: input swift_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set SWIFT_REPO and SWIFT_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,swift))
	make wait
	oc kustomize ${DEPLOY_DIR} | oc apply -f -

.PHONY: swift_deploy_cleanup
swift_deploy_cleanup: ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,swift))
	oc kustomize ${DEPLOY_DIR} | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} -Rf ${OPERATOR_BASE_DIR}/swift-operator ${DEPLOY_DIR}

##@ CERT-MANAGER
.PHONY: certmanager
certmanager: export NAMESPACE=cert-manager
certmanager: export OPERATOR_NAMESPACE=cert-manager-operator
certmanager: export CHANNEL=stable-v1
certmanager: ## installs cert-manager operator in the cert-manager-operator namespace, cert-manager runs it cert-manager namespace
	$(eval $(call vars,$@,cert-manager))
ifeq ($(OKD), true)
	$(MAKE) operator_namespace OPERATOR_NAMESPACE=cert-manager
	bash scripts/gen-olm-cert-manager-okd.sh
	oc apply -f ${OPERATOR_DIR}
	while ! (oc get pod --no-headers=true -l app=cainjector -n ${NAMESPACE} | grep "cert-manager-cainjector"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} -l app=cainjector --for condition=Ready --timeout=$(CERTMANAGER_TIMEOUT)
	while ! (oc get pod --no-headers=true -l app=webhook -n ${NAMESPACE} | grep "cert-manager-webhook"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} -l app=webhook --for condition=Ready --timeout=$(CERTMANAGER_TIMEOUT)
	while ! (oc get pod --no-headers=true -l app=cert-manager -n ${NAMESPACE} | grep "cert-manager"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} -l app=cert-manager --for condition=Ready --timeout=$(CERTMANAGER_TIMEOUT)
else
	$(MAKE) operator_namespace
	bash scripts/gen-olm-cert-manager.sh
	oc apply -f ${OPERATOR_DIR}
	while ! (oc get pod --no-headers=true -l name=cert-manager-operator -n ${OPERATOR_NAMESPACE}| grep "cert-manager-operator"); do sleep 10; done
	oc wait pod -n ${OPERATOR_NAMESPACE} --for condition=Ready -l name=cert-manager-operator --timeout=$(CERTMANAGER_TIMEOUT)
	while ! (oc get pod --no-headers=true -l app=cainjector -n ${NAMESPACE} | grep "cert-manager-cainjector"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} -l app=cainjector --for condition=Ready --timeout=$(CERTMANAGER_TIMEOUT)
	while ! (oc get pod --no-headers=true -l app=webhook -n ${NAMESPACE} | grep "cert-manager-webhook"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} -l app=webhook --for condition=Ready --timeout=$(CERTMANAGER_TIMEOUT)
	while ! (oc get pod --no-headers=true -l app=cert-manager -n ${NAMESPACE} | grep "cert-manager"); do sleep 10; done
	oc wait pod -n ${NAMESPACE} -l app=cert-manager --for condition=Ready --timeout=$(CERTMANAGER_TIMEOUT)
endif

.PHONY: certmanager_cleanup
certmanager_cleanup: export NAMESPACE=cert-manager
certmanager_cleanup: export OPERATOR_NAMESPACE=cert-manager-operator
certmanager_cleanup:
	oc delete -n ${OPERATOR_NAMESPACE} operatorgroup --all --ignore-not-found=true
	oc delete -n ${OPERATOR_NAMESPACE} subscription --all --ignore-not-found=true
	oc delete -n ${OPERATOR_NAMESPACE} csv --all --ignore-not-found=true
	oc delete -n ${NAMESPACE} installplan --all --ignore-not-found=true
	oc delete -n cert-manager deployment --all

.PHONY: validate_marketplace
validate_marketplace: ## validates that the openshift marketplace is healthy and has the packagemanifests for the required operators
	$(eval $(call vars,$@,openshift-marketplace))
ifeq ($(OKD), true)
	bash scripts/validate-marketplace-okd.sh
else
	bash scripts/validate-marketplace.sh
endif

##@ REDIS
.PHONY: redis_deploy_prep
redis_deploy_prep: export KIND=Redis
redis_deploy_prep: export NAME=redis
redis_deploy_prep: export IMAGE=${REDIS_DEPL_IMG}
redis_deploy_prep: export REPO=${INFRA_REPO}
redis_deploy_prep: export BRANCH=${INFRA_BRANCH}
redis_deploy_prep: export HASH=${INFRA_COMMIT_HASH}
redis_deploy_prep: export ALT_CHECKOUT=redis
redis_deploy_prep: redis_deploy_cleanup ## prepares the CR to install the service based on the service sample file REDIS
	$(eval $(call vars,$@,infra))
	mkdir -p ${OPERATOR_BASE_DIR} ${OPERATOR_DIR} ${OUT}/${NAMESPACE}/infra-redis/cr
	bash scripts/clone-operator-repo.sh
	cp ${REDIS_CR} ${OUT}/${NAMESPACE}/infra-redis/cr
	DEPLOY_DIR=${OUT}/${NAMESPACE}/infra-redis/cr bash scripts/gen-service-kustomize.sh

.PHONY: redis_deploy
redis_deploy: input redis_deploy_prep ## installs the service instance using kustomize. Runs prep step in advance. Set INFRA_REPO and INFRA_BRANCH to deploy from a custom repo.
	$(eval $(call vars,$@,infra))
	make wait
	DEPLOY_DIR=${OUT}/${NAMESPACE}/infra-redis/cr bash scripts/operator-deploy-resources.sh

.PHONY: redis_deploy_cleanup
redis_deploy_cleanup: namespace ## cleans up the service instance, Does not affect the operator.
	$(eval $(call vars,$@,infra))
	oc kustomize ${OUT}/${NAMESPACE}/infra-redis/cr | oc delete --ignore-not-found=true -f -
	${CLEANUP_DIR_CMD} ${OPERATOR_BASE_DIR}/infra-operator-redis ${OUT}/${NAMESPACE}/infra-redis/cr
