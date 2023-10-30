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

set -e

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root."
    exit 1
fi

function usage {
    echo
    echo "options:"
    echo "  --create        Create NAT64 router"
    echo "  --cleanup       Destroy NAT64 router"
    echo
}

WORK_DIR=${WORK_DIR:-$HOME/.nat64-router-workdir}
LIBVIRT_URL=${LIBVIRT_URL:-qemu:///system}
VIRSH_CMD=${VIRSH_CMD:-virsh --connect=$LIBVIRT_URL}
LIBVIRT_STORAGE_POOL=${LIBVIRT_STORAGE_POOL:-default}

NETWORK_NAME=${NETWORK_NAME:-nat64}
IPV4_NETWORK_IPADDRESS=${IPV4_NETWORK_IPADDRESS:-172.30.0.1}
IPV6_NETWORK_IPADDRESS=${IPV6_NETWORK_IPADDRESS:-fd00:abcd:abcd:fc00::1}
NAT64_HOST_MAC=${NAT64_HOST_MAC:-$(echo -n 52:54:00; dd bs=1 count=3 if=/dev/random 2>/dev/null | hexdump -v -e '/1 "-%02X"' | tr '-' ':')}
NAT64_HOST_IPV4=${NAT64_HOST_IPV4:-172.30.0.2/24}
NAT64_HOST_IPV6=${NAT64_HOST_IPV6:-fd00:abcd:abcd:fc00::2/64}
NAT64_ROUTER_IPV4=${NAT64_ROUTER_IPV4:-127.0.1.254/32}
NAT64_TAYGA_IPV4=${NAT64_TAYGA_IPV4:-192.168.255.1}
NAT64_TAYGA_IPV6=${NAT64_TAYGA_IPV6:-fd00:abcd:abcd:fc00::3}
NAT64_TAYGA_DYNAMIC_POOL=${NAT64_TAYGA_DYNAMIC_POOL:-192.168.255.0/24}
NAT64_TAYGA_IPV6_PREFIX=${NAT64_TAYGA_IPV6_PREFIX:-fd00:abcd:abcd:fcff::/96}
NAT64_IPV6_NETWORK=${NAT64_IPV6_NETWORK:-fd00:abcd:abcd:fc00::/64}

NAT64_INSTANCE_NAME=${NAT64_INSTANCE_NAME:-nat64-router}
NAT64_INSTANCE_MEMORY=${NAT64_INSTANCE_MEMORY:-2048}
NAT64_INSTANCE_OS_VARIANT=${NAT64_INSTANCE_OS_VARIANT:-fedora38}
NAT64_INSTANCE_DISK_SIZE=${NAT64_INSTANCE_DISK_SIZE:-20}
VIRT_TYPE=${VIRT_TYPE:-kvm}
NET_MODEL=${NET_MODEL:-virtio}
SSH_PUB_KEY=${SSH_PUB_KEY:-${HOME}/.ssh/id_rsa.pub}
FEDORA_IMG=Fedora-Cloud-Base-38-1.6.x86_64.qcow2
FEDORA_IMG_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/${FEDORA_IMG}
UPDATE_PACKAGES=${UPDATE_PACKAGES:-true}

mkdir -p "${WORK_DIR}"

function get_fedora_cloud_image {
    pushd ${WORK_DIR}

    # Get fedora cloud image
    if ! [ -f ${FEDORA_IMG} ]; then
        curl -o ${FEDORA_IMG} -L $FEDORA_IMG_URL
    fi

    popd
}

function create_cloud_init_data {
    pushd ${WORK_DIR}

    # Write nat64-router cloud-init meta-data
    cat << EOF > nat64_router_meta_data.yaml
instance-id: nat64-router
local-hostname: nat64-router
EOF

    # Write nat64-router cloud-init network-data
    cat << EOF > nat64_router_network_data.yaml
network:
  version: 2
  ethernets:
    id0:
      match:
         macaddress: ${NAT64_HOST_MAC}
      addresses:
        - ${NAT64_HOST_IPV4}
        - ${NAT64_HOST_IPV6}
      routes:
        - to: 0.0.0.0/0
          via: ${IPV4_NETWORK_IPADDRESS%%/*}
          on-link: true
        - to: ::/0
          via: ${IPV6_NETWORK_IPADDRESS%%/*}
          on-link: true
      nameservers:
        addresses:
          - ${IPV4_NETWORK_IPADDRESS%%/*}
EOF

    # Write nat64-router cloud-init user-data
    cat << EOF > nat64_router_user_data.yaml
#cloud-config
ssh_authorized_keys:
  - $(cat ${SSH_PUB_KEY})
package_upgrade: ${UPDATE_PACKAGES}
packages:
  - vim-enhanced
  - nftables
  - unbound
  - tayga
  - radvd
  - bind-utils
write_files:
  - path: /etc/radvd.conf
    owner: root:root
    content: |
      interface eth0
      {
          AdvSendAdvert on;
          AdvManagedFlag on;
          AdvOtherConfigFlag on;
          MinRtrAdvInterval 30;
          MaxRtrAdvInterval 100;
          AdvRASolicitedUnicast on;
          AdvLinkMTU 1500;
          prefix ${NAT64_IPV6_NETWORK}
          {
              AdvOnLink on;
              AdvAutonomous off;
              AdvRouterAddr on;
          };
      };
  - path: /etc/nftables/main64.nft
    owner: root:root
    permissions: '0600'
    content: |
      # drop any existing nftables ruleset
      flush ruleset

      # a common table for both IPv4 and IPv6
      table inet nftables_svc {
          # protocols to allow
          set allowed_protocols {
              type inet_proto
              elements = { icmp, icmpv6 }
          }
          # interfaces to accept any traffic on
          set allowed_interfaces {
              type ifname
              elements = { "lo" }
          }
          # services to allow (TCP)
          set allowed_tcp_dports {
              type inet_service
              elements = { domain, ssh }
          }
          # services to allow (UDP)
          set allowed_udp_dports {
              type inet_service
              elements = { domain }
          }
          # this chain gathers all accept conditions
          chain allow {
              ct state established,related accept
              meta l4proto @allowed_protocols accept
              iifname @allowed_interfaces accept
              tcp dport @allowed_tcp_dports accept
              udp dport @allowed_udp_dports accept
          }
          # base-chain for traffic to this host
          chain INPUT {
              type filter hook input priority filter + 20
              policy accept

              jump allow
              reject with icmpx type port-unreachable
          }
      }
      include "/etc/nftables/nat64.nft"
  - path: /etc/nftables/nat64.nft
    owner: root:root
    permissions: '0600'
    content: |
      table ip nftables_svc {
        set masq_interfaces {
          type ifname
          elements = { "nat64" }
        }
        set masq_ips {
          type ipv4_addr
          flags interval
          elements = { ${NAT64_TAYGA_DYNAMIC_POOL} }
        }
        chain do_masquerade {
          meta iif > 0 th sport < 16384 th dport >= 32768 masquerade random
          masquerade
        }
        chain POSTROUTING {
          type nat hook postrouting priority srcnat + 20
          policy accept

          oifname @masq_interfaces jump do_masquerade
          ip saddr @masq_ips jump do_masquerade
        }
      }
  - path: /etc/unbound/conf.d/forward-zones.conf
    content: |
      forward-zone:
          name: "."
          forward-addr: ${IPV4_NETWORK_IPADDRESS%%/*}
  - path: /etc/unbound/unbound.conf
    content: |
      include: "/etc/unbound/conf.d/*.conf"
      server:
        use-systemd: yes
        module-config: "dns64 validator iterator"
        interface: ${NAT64_HOST_IPV6%%/*}
        access-control: ::0/0 refuse
        access-control: ${NAT64_IPV6_NETWORK} allow
        dns64-prefix: ${NAT64_TAYGA_IPV6_PREFIX}
  - path: /etc/tayga/default.conf
    content: |
      tun-device nat64
      # TAYGA's IPv4 address
      ipv4-addr ${NAT64_TAYGA_IPV4}
      prefix ${NAT64_TAYGA_IPV6_PREFIX}
      # Dynamic pool prefix
      dynamic-pool ${NAT64_TAYGA_DYNAMIC_POOL}
      # Persistent data storage directory
      data-dir /var/lib/tayga/default
  - path: /etc/sysctl.d/80-tayga.conf
    content: |
      net.ipv4.ip_forward=1
      net.ipv6.conf.all.forwarding=1
  - path: /etc/NetworkManager/conf.d/nat64-manage.conf
    owner: root:root
    permissions: '0600'
    content: |
      [device-nat64]
      match-device=interface-name:nat64
      managed=1
  - path: /etc/NetworkManager/system-connections/nat64.nmconnection
    owner: root:root
    permissions: '0600'
    content: |
      [connection]
      id=nat64
      type=tun
      autoconnect=true
      interface-name=nat64

      [tun]
      pi=true

      [ipv4]
      address1=${NAT64_ROUTER_IPV4}
      route1=${NAT64_TAYGA_DYNAMIC_POOL}
      method=manual

      [ipv6]
      addr-gen-mode=default
      address1=${NAT64_TAYGA_IPV6}/128
      route1=${NAT64_TAYGA_IPV6_PREFIX}
      method=manual

      [proxy]
runcmd:
  - [ 'sh', '-c', 'echo "include \"/etc/nftables/main64.nft\"" | tee -a /etc/sysconfig/nftables.conf' ]
  - [ 'systemctl', 'daemon-reload' ]
  - [ 'systemctl', 'enable', 'unbound.service' ]
  - [ 'systemctl', 'enable', 'tayga@default.service' ]
  - [ 'systemctl', 'enable', 'nftables.service' ]
  - [ 'systemctl', 'enable', 'radvd.service' ]
power_state:
  mode: poweroff
  message: Bye Bye
  delay: now
  timeout: 30
  condition: True
EOF

    popd
}


function create_nat64_vm_image {
    pushd ${WORK_DIR}

    qemu-img convert -f qcow2 -O qcow2 ${FEDORA_IMG} NAT64_${FEDORA_IMG}
    qemu-img resize NAT64_${FEDORA_IMG} ${NAT64_INSTANCE_DISK_SIZE}G
    size=$(stat -Lc%s NAT64_${FEDORA_IMG})
    sudo virsh vol-create-as ${LIBVIRT_STORAGE_POOL} NAT64_${FEDORA_IMG} ${size} --format raw
    sudo virsh vol-upload --pool ${LIBVIRT_STORAGE_POOL} NAT64_${FEDORA_IMG} NAT64_${FEDORA_IMG}

    popd
}

function create_nat64_vm {
    pushd ${WORK_DIR}

    virt-install --connect ${LIBVIRT_URL} \
        --name ${NAT64_INSTANCE_NAME} \
        --memory ${NAT64_INSTANCE_MEMORY} \
        --vcpus 2 \
        --os-variant ${NAT64_INSTANCE_OS_VARIANT} \
        --disk vol=${LIBVIRT_STORAGE_POOL}/NAT64_${FEDORA_IMG} \
        --network network=${NETWORK_NAME},mac.address=${NAT64_HOST_MAC},model=${NET_MODEL} \
        --virt-type ${VIRT_TYPE} \
        --cloud-init disable=on,user-data=nat64_router_user_data.yaml,meta-data=nat64_router_meta_data.yaml,network-config=nat64_router_network_data.yaml

    popd

    echo "NAT64 router instance ${NAT64_INSTANCE_NAME} created"
    ${VIRSH_CMD} start ${NAT64_INSTANCE_NAME}
}

function cleanup_nat64_vm {
    if ${VIRSH_CMD} list --all --name | grep --silent "^${NAT64_INSTANCE_NAME}\$"; then
        ${VIRSH_CMD} destroy "${NAT64_INSTANCE_NAME}" || true
        ${VIRSH_CMD} undefine "${NAT64_INSTANCE_NAME}" --nvram --remove-all-storage
        echo "NAT64 router instance: ${NAT64_INSTANCE_NAME} deleted"
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

if [ "$ACTION" = "CREATE" ]; then
    get_fedora_cloud_image
    create_cloud_init_data
    create_nat64_vm_image
    create_nat64_vm
elif [ "$ACTION" = "CLEANUP" ]; then
    cleanup_nat64_vm
fi

exit 0
