#!/usr/bin/env python3
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

import argparse
import re
import sys
import yaml


def parse_opts(argv):
    parser = argparse.ArgumentParser(
            description='Create an ansible inventory from a yaml file similar'
                        'to the one output by `openstack overcloud node provision`.'
                        '')
    parser.add_argument('-d', '--deployed-server', metavar='DEPLOYED',
                        help="INPUT Relative path to a deployed server file. "
                        "It should contain a DeployedServerPortMap. "
                        "For example, config-download.yaml",
                        required=True)
    parser.add_argument('-u', '--ssh-user', metavar='SSH_USER',
                        help="INPUT user who can SSH to all nodes in DEPLOYED "
                        "(and run commands with sudo) "
                        "which will be stored in INVETORY. "
                        "Default: zuul",
                        default='zuul')
    parser.add_argument('-i', '--ansible-inventory', metavar='INVENTORY',
                        help="OUTPUT Relative path to the Ansible inventory produced "
                        "by this tool. "
                        "Default: inventory.yaml",
                        default='inventory.yaml')
    opts = parser.parse_args(argv[1:])

    return opts


def get_deployed_servers(deployed_file):
    with open(deployed_file, 'r') as f:
        try:
            deployed = yaml.safe_load(f)
        except Exception:
            raise RuntimeError(
                'Invalid YAML file: {deployed_data_file}'.format(
                deployed_data_file=deployed_file))
        return deployed


def get_host_to_ip(deployed_metal):
    host_to_ip = {}
    for srv, net in deployed_metal['parameter_defaults']['DeployedServerPortMap'].items():
        h = srv.replace('-ctlplane', '')
        host_to_ip[h] = net['fixed_ips'][0]['ip_address']
    return host_to_ip


def get_groups(deployed_metal):
    host_to_ip = get_host_to_ip(deployed_metal)
    mons = {}
    osds = {}
    for role, host in deployed_metal['parameter_defaults']['HostnameMap'].items():
        osd = r".*(-computehci-|-novacompute-).*"
        mon = r".*-controller-.*"
        if re.match(mon, role):
            mons[host] = host_to_ip[host]
        if re.match(osd, role):
            osds[host] = host_to_ip[host]
    return mons, osds


def get_ip_map(deployed_metal):
    ip_map = {}
    for srv, port_map in deployed_metal['parameter_defaults']['NodePortMap'].items():
        ip_map[srv] = {}
        for net, net_map in port_map.items():
            my_key = net + "_ip"
            ip_map[srv][my_key] = net_map['ip_address']

    return ip_map


def get_undercloud_inv():
    inv = {}
    inv['Undercloud'] = {}
    inv['Undercloud']['hosts'] = {}
    inv['Undercloud']['hosts']['undercloud'] = {}
    inv['Undercloud']['vars'] = {}
    inv['Undercloud']['vars']['ansible_connection'] = 'local'
    inv['Undercloud']['vars']['ansible_host'] = 'localhost'
    return inv


def get_inventory(user, mons, osds, ip_map):
    inv = get_undercloud_inv()

    for role in ['Controller', 'ComputeHCI']:
        if role == 'Controller':
            hosts = mons
        else:
            hosts = osds
        inv[role] = {}
        inv[role]['vars'] = {}
        inv[role]['vars']['ansible_ssh_user'] = user
        inv[role]['vars']['ansible_ssh_common_args'] = "-o StrictHostKeyChecking=no"

        inv[role]['hosts'] = {}
        for host, ip in hosts.items():
            inv[role]['hosts'][host] = {}
            inv[role]['hosts'][host]['ansible_host'] = ip
            inv[role]['hosts'][host]['canonical_hostname'] = host + ".localdomain"
            for new_var, new_val in ip_map[host].items():
                inv[role]['hosts'][host][new_var] = new_val

    # hack: ci-framework ceph.yml playbook expects a "computes" group
    inv['computes'] = {}
    inv['computes']['children'] = {}
    inv['computes']['children']['ComputeHCI'] = {}

    # 'openstack overcloud ceph' expects allovercloud group
    inv['allovercloud'] = {}
    inv['allovercloud']['children'] = {}
    inv['allovercloud']['children']['ComputeHCI'] = {}
    inv['allovercloud']['children']['Controller'] = {}

    return inv


OPTS = parse_opts(sys.argv)
deployed_metal = get_deployed_servers(OPTS.deployed_server)
controller_dict, computehci_dict = get_groups(deployed_metal)
ip_map = get_ip_map(deployed_metal)
inventory = get_inventory(OPTS.ssh_user, controller_dict, computehci_dict, ip_map)

with open(OPTS.ansible_inventory , 'w') as outfile:
    yaml.dump(inventory, outfile, indent=2)
