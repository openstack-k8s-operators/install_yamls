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
