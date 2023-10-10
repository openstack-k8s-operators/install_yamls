#!/bin/bash
#
# Copyright 2023 Red Hat Inc.
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

#---
## Jinja2 template render function
# Parameter #1 is the Jinja2 template file
# Parameter #2 is the YAML/JSON file with Jinja2 variable definitions
#---
function jinja2_render {
    local j2_template_file
    local j2_vars
    j2_template_file=$1
    j2_vars_file=$2

    /usr/bin/python3 -c "
import yaml
import jinja2

with open('$j2_vars_file', 'r') as f:
    vars = yaml.safe_load(f.read())

with open('$j2_template_file', 'r') as f:
    template = f.read()

j2_template = jinja2.Template(template)

print(j2_template.render(**vars))
"
}


#---
## Get libvirt network ip subnet (CIDR)
# Parameter #1 is the libvirt network name
#---
function get_libvirt_net_ip_subnet {
    local libvirt_net
    local ip
    local prefix
    libvirt_net=$1
    ip=$(sudo virsh net-dumpxml $libvirt_net | xmllint - --xpath 'string(/network/ip/@address)')
    prefix=$(sudo virsh net-dumpxml $libvirt_net | xmllint - --xpath 'string(/network/ip/@prefix)')
    if [ -z "${prefix}" ]; then
        prefix=$(sudo virsh net-dumpxml $libvirt_net | xmllint - --xpath 'string(/network/ip/@netmask)')
    fi
    ip_version=$(/usr/bin/python3 -c "import ipaddress; print(ipaddress.ip_address('${ip}').version)")
    if [[ ${ip_version} == 4 ]]; then
        ip_subnet=$(/usr/bin/python3 -c "import ipaddress; print(ipaddress.IPv4Network('${ip}/${prefix}', strict=False))")
    elif [[ ${ip_version} == 6 ]]; then
        ip_subnet=$(/usr/bin/python3 -c "import ipaddress; print(ipaddress.IPv6Network('${ip}/${prefix}', strict=False))")
    else
        echo "Invalid ip version: '${ip_version}'"
        exit 1
    fi

    echo ${ip_subnet}
}


#---
## Get libvirt network bridge name
# Parameter #1 is the libvirt network name
#---
function get_libvirt_net_bridge {
    local libvirt_net
    libvirt_net=$1

    bridge_name=$(sudo virsh net-dumpxml ${libvirt_net} | xmllint - --xpath 'string(/network/bridge/@name)')

    echo ${bridge_name}
}
