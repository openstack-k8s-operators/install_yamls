#!/bin/bash
#
# Helper script to add custom EDPM services conditionally
# This is sourced by gen-edpm-kustomize.sh
#

# Counter to track service index
SERVICE_INDEX=0

# Function to add a service conditionally
# Usage: add_service_if <condition_var> <service_name> [<service_index>]
# Example: add_service_if ENABLE_CYBORG cyborg 1
add_service_if() {
    local condition_var=$1
    local service_name=$2
    local service_index=${3:-$SERVICE_INDEX}
    
    if [ -n "${!condition_var}" ]; then
        cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/services/${service_index}
      value: ${service_name}
EOF
        SERVICE_INDEX=$((SERVICE_INDEX + 1))
    fi
}

# Function to add repo-setup service (always added at index 0)
add_repo_setup_service() {
    cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/services/${SERVICE_INDEX}
      value: repo-setup
EOF
    SERVICE_INDEX=$((SERVICE_INDEX + 1))
}
