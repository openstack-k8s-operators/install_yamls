# Python script to automatically generate roles content for install_yamls
# To Run: python makefile_to_install_yamls.py <path to install_yamls makefile>
import os
import sys

script_path = os.path.realpath(os.path.dirname(__file__))
roles_dir = os.path.join(os.path.normpath(script_path + os.sep + os.pardir), 'roles', 'use_install_yamls')
template_file = os.path.join(roles_dir, 'templates', 'install_yamls.sh.j2')
roles_var_file = os.path.join(roles_dir, 'defaults', 'main.yaml')
command_after_makefile_vars_file = os.path.join(roles_dir, 'vars', 'command_after_make_target.yaml')
make_file = sys.argv[1]

# Content to dump in defaults/main.yaml
roles_vars = []

# Jinja conditionals to export makefile vars
export_jinja_vars = []

# Jinja conditionals to run commands
command_jinja_vars = []

# Jinja conditionals to run cleanup commands
command_cleanup_jinja_vars = []

# Content to dump in vars/command_after_make_target.yaml
command_after_makefile_vars = []

# Read the content of MakeFile
with open(make_file) as f:
    content = f.read().split('\n')

# Seperate vars in order to export it
for data in content:
    # In Makefile, vars should contain ?=
    if '?=' in data:
        k, v = data.split('?=')
        key = k.strip()
        value = v.strip()
        roles_vars.append(f'''
## The default value of {key.lower()} is {value}
# {key.lower()}: {value}''')
        # contstruct jinja for exporting makefile vars
        export_jinja_vars.append(f'''
{{% if {key.lower()} is defined %}}
# To set the value of {key}
export {key}={{{{ {key.lower()} }}}}
{{% endif %}}''')

# Seperate commands
for data in content:
    if data.startswith('.PHONY: '):
        command = data.split('.PHONY: ')[1]
        roles_vars.append(f'''
# For running **make {command}**
# Set the value of run_{command} to true
# run_{command}: false''')

        command_after_makefile_vars.append(f'''
# Add command to be executed after **make {command}**
# uncomment command_after_make_{command} var: | and add the command the below that''')

        if command.endswith('cleanup'):
            command_cleanup_jinja_vars.append(f'''
{{% if run_{command} is defined and run_{command} | bool %}}
# set run_{command} var to true to run **make {command}**
make {command}

# Command to run after command_after_make_{command} var
{{% if command_after_make_{command} is defined %}}
{{{{ command_after_make_{command} }}}}
{{% endif %}}

{{% endif %}}''')

        else:
            command_jinja_vars.append(f'''
{{% if run_{command} is defined and run_{command} | bool %}}
# set run_{command} var to true to run **make {command}**
make {command}

# Command to run after command_after_make_{command} var
{{% if command_after_make_{command} is defined %}}
{{{{ command_after_make_{command} }}}}
{{% endif %}}

{{% endif %}}''')

# Reverse the order of cleanup command
command_cleanup_jinja_vars.reverse()

# Merge list
command_list = export_jinja_vars + command_jinja_vars + command_cleanup_jinja_vars

## Write content in the file
# defaults/main.yaml
with open(roles_var_file, 'w') as f:
    f.write('\n'.join(roles_vars))

# templates/run_install_yamls.sh.j2
with open(template_file, 'w') as f:
    f.write('\n'.join(command_list))

# vars/command_after_make_target.yaml
with open(command_after_makefile_vars_file, 'w') as f:
    f.write('\n'.join(command_after_makefile_vars))