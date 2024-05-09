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

OVN_NBCTL=ovn-nbctl
OVN_SBCTL=ovn-sbctl

OVN_NB_SERVICE=ovsdbserver-nb
OVN_SB_SERVICE=ovsdbserver-sb


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
import jinja2
import os
import yaml

with open('$j2_vars_file', 'r') as f:
    vars = yaml.safe_load(f.read())

loader = jinja2.FileSystemLoader(os.path.dirname('$j2_template_file'))
env = jinja2.Environment(autoescape=True, loader=loader)
env.filters['bool'] = bool

print(env.get_template(os.path.basename('$j2_template_file')).render(**vars))
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
    ip=$(sudo virsh net-dumpxml $libvirt_net | xmllint --xpath 'string(/network/ip/@address)' -)
    prefix=$(sudo virsh net-dumpxml $libvirt_net | xmllint --xpath 'string(/network/ip/@prefix)' -)
    if [ -z "${prefix}" ]; then
        prefix=$(sudo virsh net-dumpxml $libvirt_net | xmllint --xpath 'string(/network/ip/@netmask)' -)
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
## Get libvirt network ip subnet (CIDR)
# Parameter #1 is the libvirt network name
#---
function get_libvirt_net_ip_address {
    local libvirt_net
    local ip
    libvirt_net=$1
    ip=$(sudo virsh net-dumpxml $libvirt_net | xmllint --xpath 'string(/network/ip/@address)' -)

    echo ${ip}
}

#---
## Get libvirt network bridge name
# Parameter #1 is the libvirt network name
#---
function get_libvirt_net_bridge {
    local libvirt_net
    libvirt_net=$1

    bridge_name=$(sudo virsh net-dumpxml ${libvirt_net} | xmllint --xpath 'string(/network/bridge/@name)' -)

    echo ${bridge_name}
}


## Deduplicate a separated string
# Parameter #1 is the string to deduplicate
# Parameter #2 is the delimiter/field separator
#
# Example:
#   deduplicate_string_list "foo,bar,foo,baz,bar,foo" ","
# Result:
#   foo,bar,baz
#
#---
function deduplicate_string_list {
    local cs_list
    local field_separator
    local result
    cs_list=$1
    field_separator=${2:-" "}

    result=$(echo -n "${cs_list}" | awk --field-separator="${field_separator}" '{for (i=1;i<=NF;i++) if (!a[$i]++) printf("%s%s",$i,FS)}')
    echo ${result%%"${field_separator}"}
}

#---
## Run an ovsdb-server command in a given service pod
# Parameter #1 is the OVN database abbreviation - either NB or SB
# The rest of parameters are the ctl parameters
#
# Example:
#   run_ovn_ctl_command SB list chassis
#---
function run_ovn_ctl_command {
    local db=$1
    shift
    local cmd="$@"
    local service
    local ctl

    if [ "x" = "x$db" -o "x" = "x$cmd" ]; then
        echo "At least two parameters are required, the DB type that can be either NB or SB, and then the command" 1>&2
        return 1
    fi

    if [ "$db" != "NB" -a "$db" != "SB" ]; then
        echo "Unknown DB type $db" 1>&2
        return 1
    fi

    service=OVN_${db}_SERVICE
    ctl=OVN_${db}CTL

    pod=$(oc get pods -n openstack -l service=${!service} -o name | head -n1)

    if [ $? -ne 0 -o "x$pod" = "x" ]; then
        echo "Cannot find a pod for ${!service} service" 1>&2
        return 1
    fi

    oc rsh $pod ${!ctl} $cmd
}

#---
## Run an openstack command
#
# Example:
#   run_openstack_command server list --all
#---
function run_openstack_command {
    oc rsh openstackclient openstack $@
}
