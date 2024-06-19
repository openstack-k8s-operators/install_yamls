#!/bin/bash
#
# Copyright 2024 Red Hat Inc.
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

#
# Clones operator's repo into OPERATOR_BASE_DIR directory.
# If CHECKOUT_FROM_OPENSTACK_REF is true, it will checkout
# from operator's ref defined in openstack-operator's go.mod.
#

set -e

if [ -z "${OPERATOR_BASE_DIR}" ]; then
	echo "Please set OPERATOR_BASE_DIR"
	exit 1
fi

if [ ! -d ${OPERATOR_BASE_DIR} ]; then
	mkdir -p ${OPERATOR_BASE_DIR}
fi

if [ -z "${OPERATOR_NAME}" ]; then
	echo "Please set OPERATOR_NAME"
	exit 1
fi

if [ -z "${BRANCH}" ]; then
	BRANCH=main
fi

function pushd {
	command pushd "$@" >/dev/null
}

function popd {
	command popd "$@" >/dev/null
}

function git_clone_checkout {
	local operator=$1
	local repo=$2
	local git_opts
	# ignore branch and commit if not a remote repo
	if [[ $repo == http* ]]; then
		local branch=${3}
		eval branch=${branch}
		[[ -n "${branch}" ]] && branch="-b ${branch}"
		local hash=$4
		eval hash=${hash}
	fi
	# Remove additional quotes
	eval operator=${operator}
	eval repo=${repo}
	eval git_opts=${GIT_CLONE_OPTS}

	pushd ${OPERATOR_BASE_DIR}

	echo "Cloning repo: git clone ${git_opts} ${branch} ${repo} ${operator}-operator${ALT_CHECKOUT:+-$ALT_CHECKOUT}"
	if [ -d "${operator}-operator" ]; then
		git clone ${git_opts} ${branch} ${repo} ${operator}-operator${ALT_CHECKOUT:+-$ALT_CHECKOUT}
	fi
	if [ -n "${hash}" ]; then
		pushd ${operator}-operator${ALT_CHECKOUT:+-$ALT_CHECKOUT}
		echo "Running checkout: git checkout ${hash}"
		git checkout ${hash}
		popd
	fi

	popd
}

# Gets repo url and commit hash from openstack-operator go.mod
function get_repo_and_commit_hash {
	local OPERATOR="$1"
	pushd ${OPERATOR_BASE_DIR}/openstack-operator

	REGEX="github.com/.*/(?:openstack-)?${OPERATOR,,}-operator/.*"
	MOD_VERSION=$(go list -mod=readonly -m -json all | jq --arg regex "${REGEX}" -c -r '. | select(.Path | test($regex)?) | {path: .Path, version: .Version}')

	MOD_PATH=$(echo $MOD_VERSION | jq -r .path)
	REF=$(echo $MOD_VERSION | jq -r .version | sed -e 's|v[0-9]*.[0-9]*.[0-9]*-.*[0-9]*-\(.*\)$|\1|')

	GIT_REPO=${MOD_PATH%"/apis"}
	GIT_REPO=${GIT_REPO%"/api"}
	if [[ "$REF" == v* ]]; then
		REF=$(git ls-remote https://${GIT_REPO} | grep ${REF} | awk 'NR==1{print $1}')
	fi

	echo "https://${GIT_REPO}.git"
	echo "${REF}"
	popd
}

# Retrieve repo url and commit hash if empty
if [[ "${CHECKOUT_FROM_OPENSTACK_REF}" == true ]]; then
	# Clone openstack-operator if not yet cloned
	if [ ! -d ${OPERATOR_BASE_DIR}/openstack-operator ]; then
		git_clone_checkout openstack ${OPENSTACK_REPO} ${OPENSTACK_BRANCH} ${OPENSTACK_COMMIT_HASH}
	fi
	# Get repo url and commit hash from openstack go.mod
	readarray OUT <<<"$(get_repo_and_commit_hash ${OPERATOR_NAME})"
	if [ -z "${REPO}" ]; then
		REPO=${OUT[0]}
	fi
	if [ -z "${HASH}" ]; then
		HASH=${OUT[1]}
	fi
fi

# Clone and checkout (if hash is provided)
git_clone_checkout ${OPERATOR_NAME} ${REPO} ${BRANCH} ${HASH}
