Development environment - IPv6 NAT64 lab
========================================

Prerequisites
-------------

Network setup relies on `systemd-resolved` service enabled and used for DNS
resolution. If it's not installed on your machine (for example, if you use
RHEL), then:

#. Install the package: `dnf install -y systemd-resolved`
#. Enable and start the service: `systemctl enable --now systemd-resolved`
#. Configure it as the default resolver for the system: `ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf`

Further DNS requests initiated by the hypervisor should now go through the stub `systemd-resolved` resolver.

Overview
--------

These scripts can be used to set up an IPv6 lab utilizing [NAT64](https://en.wikipedia.org/wiki/IPv6_transition_mechanism#NAT64) and [DNS64](https://en.wikipedia.org/wiki/IPv6_transition_mechanism#DNS64) (4 to 6 translation).

To set up the lab run the scripts in order:
```bash
network.sh --create
nat64_router.sh --create
sno.sh --create
```

Short description of each scripts following ...

network.sh
----------

This script creates a libvirt network with both an IPv4 and IPv6 address, IPv4
NAT is enabled and DHCP/DNS is disabled, not managed by libvirt. Two separate
DNS server instances started, one is listening on the IPv4 address and the
other on the IPv6 address.


```bash
network.sh --create
network.sh --cleanup

options:
  --create        Create network for IPv6 NAT64 lab
  --cleanup       Destroy network for IPv6 NAT64 lab
```

* The v4 DNS service (`nat64-v4-dnsmasq.service`) is configured to filter
  any `AAAA` records. this instance uses the systems nameservers for
  forwarding.
* The v6 DNS service (`nat64-v6-dnsmasq.service`) is configured to filter
  any `A` records. This instance is configured to use the unbound DNS server
  on the NAT64 router for all forwarding.


nat64_router.sh
---------------

Starts a Fedora virtual machine and set's it up as a NAT64 router.

```bash
nat64_router.sh --create
nat64_router.sh --cleanup

options:
  --create        Create NAT64 router
  --cleanup       Destroy NAT64 router
```

* unbound - DNS server responsible for DNS64. Uses the v4 DNS service
  configured by `network.sh` as the forwarder. Since the forwarder filters
  `AAAA` records the result is that all records require translation.
* tayga - TAYGA is an out-of-kernel stateless NAT64 router
* radvd - IPv6 Router Advertisements
* nftables - Firewall for IPv4 NAT (Masqurade NAT64 pool behind a single ip
  address)


sno.sh
------

Creates a Single-node-Openshift VM, with IPv6 only connectivity.

```bash
sno.sh --create
sno.sh --cleanup

options:
  --create        Create OCP Single-Node instance lab
  --cleanup       Destroy OCP Single-Node instance lab
```

* Adds DHCPv6 configuration to the v6 DNS service
  (`nat64-v6-dnsmasq.service`).
* Uses v6 DNS service (`nat64-v6-dnsmasq.service`) for resolving names.
* DHCPv6 `dhcp-range` and `dhcp-host` record added in v6 dnsmasq instance:
  ```conf
  dhcp-range=fd00:abcd:abcd:fc00::,static,64
  dhcp-host=52:54:00:08:09:FD,[fd00:abcd:abcd:fc00::11],2m
  ```
* DNS entries for Openshift is also added to the v6 DNS service
  ```conf
  address=/sno.lab.example.com/fd00:abcd:abcd:fc00::11
  address=/apps.sno.lab.example.com/fd00:abcd:abcd:fc00::11
  host-record=api.sno.lab.example.com,fd00:abcd:abcd:fc00::11
  host-record=api-int.sno.lab.example.com,fd00:abcd:abcd:fc00::11
  ```
