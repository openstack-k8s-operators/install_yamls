# Ansible role wrapper around install_yamls Makefile

Install_yamls makefile can be used by Dev/CI/QE as a single interface to
deploy NextGen OpenStack.

use_install_yamls role is a ansible wrapper around the install_yamls Makefile.
It uses scripts/makefile_to_install_yamls.py script to generate the following
ansible role specific files.

    * defaults/main.yaml
    * templates/install_yamls.sh.j2
    * vars/command_after_make_target.yaml

## Why we need a wrapper?

Developer, CI and QE are the three consumers of install_yamls tool.
Their OpenStack deployment environment might be different based on their needs.
Each of the consumers might be exporting different variables, running different
make commands and other commands in between multiple make commands to setup
the openstack deployment.

If something went wrong, we need a way to reproduce the same environment easily.
Since Ansible is the widely used everywhere to drive the deployment. It is easy to use.
Having a wrapper around the tool allows each of the consumers to use the same role
and create a playbook to achieve the desired outcome.

When the playbook will be called, It is going to generate `install_yamls.sh` script
containing all the exported vars, commands.

One can use the same script to reproduce in the enviroment.

## What is the requirements in order to consume it?

We need a working openshift cluster, kubeconfig file and ansible installed.

## How we keep the wrapper role up to date?

Once any consumers adds a new interface to the makefile, they can run following
commands to sync the wrapper role.
```
$ cd <path_to_install_yamls>/devsetup/
$ make ansible_role_sync
cd ../ci/roles/use_install_yamls; rm -f defaults/main.yaml vars/command_after_make_target.yaml templates/install_yamls.sh.j2;
cd ../ci/scripts; python makefile_to_install_yamls.py ../../Makefile;
tree ../ci/roles/use_install_yamls;
../ci/roles/use_install_yamls
├── defaults
│   └── main.yaml
├── tasks
│   └── main.yaml
├── templates
│   └── install_yamls.sh.j2
└── vars
    └── command_after_make_target.yaml

5 directories, 4 files
```

## How the wrapper role works?

The wrapper role works on following assumptions.

* All the Install_yamls Makefile vars are defined in smallcase under defaults/main.yaml.
* In order to run any `make <target>` command, we need add `run_` as a prefix to the target name
  and set the var as `run_<target>: true` in the playbook.

  For example: We want to run `make openstack` command, then the ansible var would be
  `run_openstack: true`.

* This wrapper role also provides functionality to run custom commands after a make command.
  We need to add `command_after_make_<target>` as a var and add the command below that.

  For Example: We want to run 'oc get csv' after `make openstack` command. Then we need to
  define following var.
  command_after_make_openstack: |
    oc get csv

* If multiple cleanup commands are called, then order will be reversed based on the sequence
  defined in the Makefile

## Example playbook to consume the role

```
❯ cat example_playbook.yaml
---
- hosts: localhost
  tasks:
    - include_role:
        name: use_install_yamls
      vars:
        namespace: openstack
        openstack_img: quay.rdoproject.org/openstack-k8s-operators/openstack-operator-index:latest
        openstack_repo: "{{ ansible_user_dir }}/openstack-operator"
        openstack_branch: feature_branch
        run_openstack: true
        run_openstack_deploy: true
        command_after_make_openstack: |
          oc get csv
        command_after_make_openstack_deploy: |
          oc get pods
        run_openstack_deploy_cleanup: true
```

Here is the generated script from above playbook.
```
❯ cat ~/openstack/install_yamls.sh
export NAMESPACE=openstack
export OPENSTACK_IMG=quay.rdoproject.org/openstack-k8s-operators/openstack-operator-index:latest
export OPENSTACK_REPO=/home/chandankumar/openstack-operator
export OPENSTACK_BRANCH=feature_branch
make openstack
oc get csv
make openstack_deploy
oc get pods
make openstack_deploy_cleanup
```

