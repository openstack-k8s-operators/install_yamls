CRC_URL ?= 'https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz'
KUBEADMIN_PWD ?= 12345678
PULL_SECRET  ?= ${PWD}/pull-secret.txt

crc_storage:
.PHONY: crc
crc:
	bash scripts/crc-setup.sh ${CRC_URL} ${KUBEADMIN_PWD} ${PULL_SECRET}
	make crc_storage

.PHONY: crc_cleanup
crc_cleanup:
	# we do NOT clear ( --clear-cache ) the cache to save time on next setup
	crc delete --force
	crc cleanup
	sudo rm -f /etc/pki/ca-trust/source/anchors/crc-router-ca.pem
	sudo update-ca-trust

.PHONY: download_tools
download_tools:
	ANSIBLE_FORCE_COLOR=true ansible-playbook \
	-v -i hosts \
	download_tools.yaml
