#!/bin/bash
#
# Copyright 2022 Red Hat Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

set -ex

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit 1
fi


function usage {
    echo
    echo "options:"
    echo "  --create        Create network for IPv6 NAT64 lab"
    echo "  --cleanup       Destroy network for IPv6 NAT64 lab"
    echo
}

MY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${MY_TMP_DIR}"' EXIT

WORK_DIR="${WORK_DIR:-$HOME/.nat64-network-workdir}"

LIBVIRT_URL="${LIBVIRT_URL:-"qemu:///system"}"
VIRSH_CMD="virsh --connect=$LIBVIRT_URL"
NETWORK_NAME="${NETWORK_NAME:-nat64}"
MANAGE_FIREWALLD=${MANAGE_FIREWALLD:-true}
IPV6_NETWORK_IPADDRESS=${IPV6_NETWORK_IPADDRESS:-fd00:abcd:abcd:fc00::1/64}
IPV4_NETWORK_IPADDRESS=${IPV4_NETWORK_IPADDRESS:-172.30.0.1/24}

NAT64_IPV4_DNSMASQ_VAR_DIR=${NAT64_IPV4_DNSMASQ_VAR_DIR:-/var/lib/dnsmasq/${NETWORK_NAME}-v4}
NAT64_IPV4_DNSMASQ_CONF_DIR=${NAT64_IPV4_DNSMASQ_CONF_DIR:-/etc/${NETWORK_NAME}-v4-dnsmasq}
NAT64_IPV4_DNSMASQ_SERVICE_NAME=${NAT64_IPV4_DNSMASQ_SERVICE_NAME:-${NETWORK_NAME}-v4-dnsmasq.service}
NAT64_IPV4_DNSMASQ_SERVICE_CONF_FILE=${NAT64_IPV4_DNSMASQ_SERVICE_CONF_FILE:-${NAT64_IPV4_DNSMASQ_CONF_DIR}/dnsmasq.conf}

NAT64_IPV6_DNSMASQ_VAR_DIR=${NAT64_IPV6_DNSMASQ_VAR_DIR:-/var/lib/dnsmasq/${NETWORK_NAME}-v6}
NAT64_IPV6_DNSMASQ_CONF_DIR=${NAT64_IPV6_DNSMASQ_CONF_DIR:-/etc/${NETWORK_NAME}-v6-dnsmasq}
NAT64_IPV6_DNSMASQ_SERVICE_NAME=${NAT64_IPV6_DNSMASQ_SERVICE_NAME:-${NETWORK_NAME}-v6-dnsmasq.service}
NAT64_IPV6_DNSMASQ_SERVICE_CONF_FILE=${NAT64_IPV6_DNSMASQ_SERVICE_CONF_FILE:-${NAT64_IPV6_DNSMASQ_CONF_DIR}/dnsmasq.conf}

NAT64_HOST_IPV6=${NAT64_HOST_IPV6:-fd00:abcd:abcd:fc00::2/64}
if ! /usr/sbin/dnsmasq --test --filter-A; then
    DNSMASQ_BIN=${WORK_DIR}/sbin/dnsmasq
else
    DNSMASQ_BIN=/usr/sbin/dnsmasq
fi

mkdir -p "${WORK_DIR}"

function create_network {
    if ! ${VIRSH_CMD} net-list --all --name | grep --silent "^${NETWORK_NAME}\$"; then
        cat << EOF > "${MY_TMP_DIR}/network.xml"
<network xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
  <name>${NETWORK_NAME}</name>
  <forward mode="nat"/>
  <bridge name='${NETWORK_NAME}' stp='on' delay='0'/>
  <ip family='ipv4' address='${IPV4_NETWORK_IPADDRESS%%/*}' prefix='${IPV4_NETWORK_IPADDRESS##*/}'/>
  <ip family='ipv6' address='${IPV6_NETWORK_IPADDRESS%%/*}' prefix='${IPV6_NETWORK_IPADDRESS##*/}'/>
  <dns enable='no'/>
</network>
EOF

        if [ "${MANAGE_FIREWALLD}" = "true" ]; then
            xmlstarlet edit --omit-decl --inplace \
                --subnode '/network/bridge' --type attr --name zone \
                --value "${NETWORK_NAME}" "${MY_TMP_DIR}/network.xml"
        fi
        ${VIRSH_CMD} net-define "${MY_TMP_DIR}/network.xml"
    fi
    if ! ${VIRSH_CMD} net-list --autostart --name | grep --silent "^${NETWORK_NAME}\$"; then
        ${VIRSH_CMD} net-autostart "${NETWORK_NAME}"
    fi
    if ${VIRSH_CMD} net-list --inactive --name | grep --silent "^${NETWORK_NAME}\$"; then
        ${VIRSH_CMD} net-start "${NETWORK_NAME}"
    fi
    echo "Network ${NETWORK_NAME} created"
}

function build_dnsmasq {
    if [ ! -f ${WORK_DIR}/sbin/dnsmasq ]; then
        echo "Building DNSMASQ from source ..."
        pushd ${MY_TMP_DIR}

        # Install build dependencies
        sudo dnf install git gcc make -y

        git clone http://thekelleys.org.uk/git/dnsmasq.git
        pushd ./dnsmasq
        make
        sudo make install PREFIX=${WORK_DIR}
        # Set selinux context to bin_t
        sudo chcon -t bin_t ${WORK_DIR}/sbin/dnsmasq
        popd

        popd
    else
        echo "Skipping DNSMASQ build - binary already present in workdir ..."
    fi
}

function create_dnsmasq {
    pushd ${MY_TMP_DIR}

    sudo mkdir -p ${NAT64_IPV4_DNSMASQ_VAR_DIR}
    sudo mkdir -p ${NAT64_IPV4_DNSMASQ_CONF_DIR}/conf.d
    cat << EOF > dnsmasq-v4.conf
conf-dir=${NAT64_IPV4_DNSMASQ_CONF_DIR}/conf.d,*.conf
dhcp-leasefile=${NAT64_IPV4_DNSMASQ_VAR_DIR}/leasefile
except-interface=lo
bind-dynamic
# interface=${NETWORK_NAME}
listen-address=${IPV4_NETWORK_IPADDRESS%%/*}
log-dhcp
cache-size=1000
filter-AAAA
EOF

    sudo mkdir -p ${NAT64_IPV6_DNSMASQ_VAR_DIR}
    sudo mkdir -p ${NAT64_IPV6_DNSMASQ_CONF_DIR}/conf.d
    cat << EOF > dnsmasq-v6.conf
conf-dir=${NAT64_IPV6_DNSMASQ_CONF_DIR}/conf.d,*.conf
dhcp-leasefile=${NAT64_IPV6_DNSMASQ_VAR_DIR}/leasefile
except-interface=lo
bind-dynamic
# interface=${NETWORK_NAME}
listen-address=${IPV6_NETWORK_IPADDRESS%%/*}
no-hosts
no-resolv
server=${NAT64_HOST_IPV6%%/*}
log-dhcp
cache-size=1000
filter-A
EOF

    cat << EOF > ${NAT64_IPV4_DNSMASQ_SERVICE_NAME}
[Unit]
Description=DHCP and DNS for IPv6 NAT64 lab (IPv4 service)
Documentation=man:dnsmasq(8)
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=${DNSMASQ_BIN} --keep-in-foreground --conf-file=${NAT64_IPV4_DNSMASQ_SERVICE_CONF_FILE}
StandardError=null

[Install]
WantedBy=multi-user.target
EOF

    cat << EOF > ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}
[Unit]
Description=DHCP and DNS for IPv6 NAT64 lab (IPv6 service)
Documentation=man:dnsmasq(8)
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=${DNSMASQ_BIN} --keep-in-foreground --conf-file=${NAT64_IPV6_DNSMASQ_SERVICE_CONF_FILE}
StandardError=null

[Install]
WantedBy=multi-user.target
EOF

    sudo cp -v ${NAT64_IPV4_DNSMASQ_SERVICE_NAME} /etc/systemd/system/
    sudo cp -v ${NAT64_IPV6_DNSMASQ_SERVICE_NAME} /etc/systemd/system/
    sudo cp -v dnsmasq-v4.conf ${NAT64_IPV4_DNSMASQ_SERVICE_CONF_FILE}
    sudo cp -v dnsmasq-v6.conf ${NAT64_IPV6_DNSMASQ_SERVICE_CONF_FILE}
    sudo systemctl daemon-reload
    sudo systemctl enable ${NAT64_IPV4_DNSMASQ_SERVICE_NAME}
    sudo systemctl start ${NAT64_IPV4_DNSMASQ_SERVICE_NAME}
    sudo systemctl enable ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}
    sudo systemctl start ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}

    sudo resolvectl dns nat64 ${IPV6_NETWORK_IPADDRESS%%/*}#lab.example.com
    sudo resolvectl domain nat64 lab.example.com

    popd
}

function cleanup_dnsmasq {
    if sudo systemctl is-active ${NAT64_IPV4_DNSMASQ_SERVICE_NAME}; then
        sudo systemctl stop ${NAT64_IPV4_DNSMASQ_SERVICE_NAME}
    fi
    if sudo systemctl is-enabled ${NAT64_IPV4_DNSMASQ_SERVICE_NAME}; then
        sudo systemctl disable ${NAT64_IPV4_DNSMASQ_SERVICE_NAME}
    fi
    if sudo systemctl is-active ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}; then
        sudo systemctl stop ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}
    fi
    if sudo systemctl is-enabled ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}; then
        sudo systemctl disable ${NAT64_IPV6_DNSMASQ_SERVICE_NAME}
    fi
    if sudo test -f /etc/systemd/system/${NAT64_IPV4_DNSMASQ_SERVICE_NAME}; then
        sudo rm /etc/systemd/system/${NAT64_IPV4_DNSMASQ_SERVICE_NAME}
    fi
    if sudo test -f /etc/systemd/system/${NAT64_IPV6_DNSMASQ_SERVICE_NAME}; then
        sudo rm /etc/systemd/system/${NAT64_IPV6_DNSMASQ_SERVICE_NAME}
    fi
    if sudo test -f ${NAT64_IPV4_DNSMASQ_VAR_DIR}/leasefile; then
        sudo rm ${NAT64_IPV4_DNSMASQ_VAR_DIR}/leasefile
    fi
    if sudo test -d ${NAT64_IPV4_DNSMASQ_CONF_DIR}; then
        sudo rm -r  ${NAT64_IPV4_DNSMASQ_CONF_DIR}
    fi
    if sudo test -f ${NAT64_IPV6_DNSMASQ_VAR_DIR}/leasefile; then
        sudo rm ${NAT64_IPV6_DNSMASQ_VAR_DIR}/leasefile
    fi
    if sudo test -d ${NAT64_IPV6_DNSMASQ_CONF_DIR}; then
        sudo rm -r ${NAT64_IPV6_DNSMASQ_CONF_DIR}
    fi
}

function cleanup_network {
    if ${VIRSH_CMD} net-list --all --name | grep --silent "^${NETWORK_NAME}\$"; then
        if ! ${VIRSH_CMD} net-list --inactive --name | grep --silent "^${NETWORK_NAME}\$"; then
            ${VIRSH_CMD} net-destroy ${NETWORK_NAME}
        fi
        ${VIRSH_CMD} net-undefine ${NETWORK_NAME}
        echo "Network: ${NETWORK_NAME} deleted"
    fi
}

function create_firewalld_config {
    if ! sudo systemctl is-active firewalld.service; then
        echo "firewalld.service not active, enable it or disable firewalld managment (MANAGE_FIREWALLD=false)"
        exit 1
    fi
    sudo firewall-cmd --permanent --new-zone=${NETWORK_NAME}
    sudo firewall-cmd --permanent --zone=${NETWORK_NAME} \
        --add-rich-rule="rule priority=\"32767\" reject"
    sudo firewall-cmd --permanent --zone=${NETWORK_NAME} --set-target="ACCEPT"
    sudo firewall-cmd --permanent --zone=${NETWORK_NAME} \
        --add-protocol=icmp --add-protocol=ipv6-icmp
    sudo firewall-cmd --permanent --zone=${NETWORK_NAME} \
        --add-service=http --add-service=https --add-service=dns \
        --add-service=ssh --add-service=dhcp --add-service=dhcpv6
    sudo firewall-cmd --reload
}

function cleanup_firewalld_config {
    if ! sudo systemctl is-active firewalld.service; then
        echo "firewalld.service not active, enable it or disable firewalld managment (MANAGE_FIREWALLD=false)"
        exit 1
    fi
    sudo firewall-cmd --permanent --delete-zone=${NETWORK_NAME}
}

function create {
    if [ "${MANAGE_FIREWALLD}" = "true" ]; then
        create_firewalld_config
    fi
    create_network
    if ! /usr/sbin/dnsmasq --test --filter-A; then
        build_dnsmasq
    fi
    create_dnsmasq
}

function cleanup {
    cleanup_dnsmasq
    cleanup_network
    if [ "${MANAGE_FIREWALLD}" = "true" ]; then
        cleanup_firewalld_config
    fi
}

case "$1" in
    "--create")
        ACTION="CREATE";
    ;;
    "--cleanup")
        ACTION="CLEANUP";
    ;;
    *)
        echo >&2 "Invalid option: $*";
        usage;
        exit 1
    ;;
esac

if [ -z "${ACTION}" ]; then
    echo "Not enough input arguments"
    usage
    exit 1
fi

if [ "${ACTION}" == "CREATE" ]; then
    create
elif [ "${ACTION}" == "CLEANUP" ]; then
    cleanup
fi
