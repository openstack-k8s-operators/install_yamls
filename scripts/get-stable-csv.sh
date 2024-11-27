#!/bin/bash

set -ex

if [ -z "$REPO_DIR" ]; then
    echo "repo directory need to be specificed."
    exit 1
fi

if [ -z "$BRANCH" ]; then
    echo "stable branch need to be specificed."
    exit 1
fi

if [ -z "$REGISTRY" ]; then
    echo "registry needs to be specificed."
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "namespace needs to be specificed."
    exit 1
fi

pushd ${REPO_DIR} >/dev/null
commits=$(git log --reverse  remotes/origin/main..remotes/origin/${BRANCH} --pretty=format:%H)

for ref in $commits; do
    image=$(curl -s https://${REGISTRY}/api/v1/repository/${NAMESPACE}/openstack-operator-index/tag/?onlyActiveTags=true\&filter_tag_name=like:$ref| jq -r .tags[].name)
    if [[ -n $image ]]; then
        echo $image
        popd >/dev/null
        exit 0
    fi;
done

popd >/dev/null
exit 1
