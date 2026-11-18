#!/bin/bash
#
# KUTTL test runner for serial and parallel execution.
#
# Current Makefile integration is limited to keystone_kuttl and
# openstack_kuttl. Other service *_kuttl targets do not invoke this runner, so
# KUTTL_PARALLEL_COUNT does not affect them. To enable another service, wire
# its Makefile target to this runner and provide compatible lifecycle targets.
#
# Usage:
#   kuttl-runner.sh <SERVICE> <KUTTL_DIR> <NAMESPACE_BASE> <PARALLEL_COUNT> <KUTTL_CONF>
#
# Arguments:
#   SERVICE         - Service name. Currently "keystone" or "openstack" in
#                     the Makefile. Used to construct make targets:
#                     ${SERVICE}_kuttl_prep, ${SERVICE}_kuttl_run,
#                     ${SERVICE}_kuttl_deploy_cleanup, ${SERVICE}_kuttl_cleanup.
#   KUTTL_DIR       - Path to the test directory containing test subdirectories.
#   NAMESPACE_BASE  - Base namespace name (e.g. "keystone-kuttl-tests").
#   PARALLEL_COUNT  - Number of parallel workers. Defaults to 1 (serial).
#   KUTTL_CONF      - Path to the kuttl-test.yaml config file. In parallel mode,
#                     per-worker copies are generated with updated namespace and
#                     reportName fields.
#
# In serial mode (PARALLEL_COUNT <= 1), runs prep/run/cleanup sequentially in
# a single namespace -- functionally identical to the traditional make target.
#
# In parallel mode (PARALLEL_COUNT > 1), splits test subdirectories across N
# workers via kuttl's --test regex filter, runs prep per namespace, executes
# tests in parallel, then cleans up each namespace.

set -euo pipefail

declare -a pids=()
cleanup_bg() {
    for pid in "${pids[@]}"; do
        if kill -0 "${pid}" 2>/dev/null; then
            pkill -P "${pid}" 2>/dev/null || true
            kill "${pid}" 2>/dev/null || true
            wait "${pid}" 2>/dev/null || true
        fi
    done
}
trap cleanup_bg EXIT

SERVICE="${1:?SERVICE is required}"
KUTTL_DIR="${2:?KUTTL_DIR is required}"
NAMESPACE_BASE="${3:?NAMESPACE_BASE is required}"
if [[ "$#" -eq 4 ]]; then
    N=1
    KUTTL_CONF="$4"
else
    N="${4:-1}"
    KUTTL_CONF="${5:?KUTTL_CONF is required}"
fi
SERVICE_UPPER="$(echo "${SERVICE}" | tr '[:lower:]' '[:upper:]')"
KUTTL_CONF_VAR="${SERVICE_UPPER}_KUTTL_CONF"

if [[ "$N" -le 0 ]]; then
    N=1
fi

if [[ "$N" -eq 1 ]]; then
    export NAMESPACE="${NAMESPACE_BASE}"
    make "${SERVICE}_kuttl_prep"
    make wait
    make "${SERVICE}_kuttl_run"
    make "${SERVICE}_kuttl_cleanup"
    exit 0
fi

# -- Parallel path --

# Prep the first namespace first -- this clones the operator repo and creates
# the test directory, which we need to enumerate before prepping the rest.
echo "=== Preparing namespace ${NAMESPACE_BASE}-0 ==="
prep_env=(NAMESPACE="${NAMESPACE_BASE}-0" CRC_STORAGE_NAMESPACE="${NAMESPACE_BASE}-0" STORAGE_ID="worker-0")
if [[ "${SERVICE}" == "openstack" ]]; then
    prep_env+=(STORAGE_CLASS="local-storage-worker-0")
fi
env "${prep_env[@]}" make "${SERVICE}_kuttl_prep"
env "${prep_env[@]}" make wait

tests=()
for d in "${KUTTL_DIR}"/*/; do
    [[ -d "$d" ]] || continue
    tests+=("$(basename "$d")")
done

num_tests=${#tests[@]}
if [[ "$num_tests" -eq 0 ]]; then
    echo "ERROR: no test subdirectories found in ${KUTTL_DIR}" >&2
    exit 1
fi

if [[ "$N" -gt "$num_tests" ]]; then
    echo "Reducing worker count from ${N} to ${num_tests} (number of tests)"
    N=$num_tests
fi

# Round-robin assign tests to workers
declare -a worker_tests
for i in $(seq 0 $((N - 1))); do
    worker_tests[$i]=""
done

for i in "${!tests[@]}"; do
    bucket=$((i % N))
    if [[ -n "${worker_tests[$bucket]}" ]]; then
        worker_tests[$bucket]="${worker_tests[$bucket]}|${tests[$i]}"
    else
        worker_tests[$bucket]="${tests[$i]}"
    fi
done

echo "=== Parallel KUTTL run: ${num_tests} tests across ${N} workers ==="
for i in $(seq 0 $((N - 1))); do
    echo "  Worker ${i}: ${worker_tests[$i]}"
done

# Prep remaining namespaces
for i in $(seq 1 $((N - 1))); do
    ns="${NAMESPACE_BASE}-${i}"
    echo "=== Preparing namespace ${ns} ==="
    prep_env=(NAMESPACE="${ns}" CRC_STORAGE_NAMESPACE="${ns}" STORAGE_ID="worker-${i}")
    if [[ "${SERVICE}" == "openstack" ]]; then
        prep_env+=(STORAGE_CLASS="local-storage-worker-${i}")
    fi
    env "${prep_env[@]}" make "${SERVICE}_kuttl_prep"
    env "${prep_env[@]}" make wait
done

# Generate per-worker KUTTL configs. OpenStack workers also get isolated
# copies of the operator test tree so their sample CRs use worker-specific
# StorageClasses. The shared local-storage class otherwise lets either
# worker claim the other worker's PVs.
declare -a worker_conf
declare -a worker_kuttl_dir
declare -a worker_repo_dir
declare -a worker_storage_class
source_repo=""
if [[ "${SERVICE}" == "openstack" ]]; then
    source_repo="$(cd "${KUTTL_DIR}/../../.." && pwd -P)"
fi
for i in $(seq 0 $((N - 1))); do
    ns="${NAMESPACE_BASE}-${i}"
    if [[ "${SERVICE}" == "openstack" ]]; then
        worker_storage_class[$i]="local-storage-worker-${i}"
        repo="/tmp/install-yamls-kuttl-$$-worker-${i}"
        rm -rf -- "${repo}"
        cp -a "${source_repo}" "${repo}"
        # KUTTL rewrites resource namespaces from its config, but shell
        # commands embedded in test files and namespace fields used by
        # assertions can still refer to the base namespace literally. Keep
        # each worker's copied test suite scoped to its own namespace.
        while IFS= read -r -d '' file; do
            sed -i "s|${NAMESPACE_BASE}|${ns}|g" "${file}"
        done < <(rg -l --null --fixed-strings "${NAMESPACE_BASE}" "${repo}/test/kuttl/tests")
        while IFS= read -r -d '' file; do
            sed -i "s/local-storage/${worker_storage_class[$i]}/g" "${file}"
        done < <(rg -l --null 'local-storage' "${repo}/config/samples" "${repo}/test/kuttl")
        wconf="${repo}/kuttl-test-worker-${i}.yaml"
        worker_kuttl_dir[$i]="${repo}/test/kuttl/tests"
        worker_repo_dir[$i]="${repo}"
    else
        wconf="$(dirname "${KUTTL_CONF}")/kuttl-test-worker-${i}.yaml"
        worker_kuttl_dir[$i]="${KUTTL_DIR}"
        worker_storage_class[$i]=""
    fi
    sed -e "s|${NAMESPACE_BASE}|${ns}|g" \
        -e "s|^reportName:.*|reportName: kuttl-report-${SERVICE}-worker-${i}|" \
        -e "s|local-storage|${worker_storage_class[$i]:-local-storage}|g" \
        "${KUTTL_CONF}" > "${wconf}"
    worker_conf[$i]="${wconf}"
done

# Previous interrupted runs can leave data plane resources behind in the
# persistent worker namespaces. These CRs contain hostnames that the operator
# validates across NodeSets, so remove stale test resources before workers
# start and recreate them.
if [[ "${SERVICE}" == "openstack" ]]; then
    for i in $(seq 0 $((N - 1))); do
        ns="${NAMESPACE_BASE}-${i}"
        echo "=== Removing stale data plane test resources from ${ns} ==="
        oc delete openstackdataplanedeployments --all -n "${ns}" --ignore-not-found=true --timeout=120s
        oc delete openstackdataplanenodesets --all -n "${ns}" --ignore-not-found=true --timeout=120s
        oc delete openstackdataplaneservices --all -n "${ns}" --ignore-not-found=true --timeout=120s
        oc delete ipsets.network.openstack.org --all -n "${ns}" --ignore-not-found=true --timeout=120s
    done
fi

# Run tests in parallel
log_dir="${ARTIFACTS_DIR:-/tmp}/kuttl-parallel-logs"
mkdir -p "${log_dir}"

declare -a worker_ns
declare -a log_files

for i in $(seq 0 $((N - 1))); do
    ns="${NAMESPACE_BASE}-${i}"
    regex="^(${worker_tests[$i]})$"
    # Make expands environment variables in recipes; double dollar signs so
    # the end-of-regex anchor reaches the shell unchanged.
    make_regex="${regex//\$/\$\$}"
    log_file="${log_dir}/worker-${i}.log"
    worker_ns[$i]="$ns"
    log_files[$i]="${log_file}"
    : > "${log_file}"

    echo "=== Starting worker ${i} in namespace ${ns} (log: ${log_file}) ==="
    worker_env=(NAMESPACE="${ns}" CRC_STORAGE_NAMESPACE="${ns}" STORAGE_ID="worker-${i}" SKIP_CONTEXT_SWITCH=true)
    if [[ "${SERVICE}" == "openstack" ]]; then
        worker_env+=(STORAGE_CLASS="${worker_storage_class[$i]}" OPENSTACK_KUTTL_DIR="${worker_kuttl_dir[$i]}")
    fi
    worker_env+=("${KUTTL_CONF_VAR}=${worker_conf[$i]}" "KUTTL_ARGS=--test '${make_regex}'" "KUTTL_TEST_FILTER=${make_regex}")
    (
        timeout "${KUTTL_WORKER_TIMEOUT:-7200}" \
            env "${worker_env[@]}" \
            make "${SERVICE}_kuttl_run" >> "${log_file}" 2>&1
    ) &
    pids[$i]=$!
done

# Wait for all workers and collect exit codes.
# If any worker fails, kill remaining workers immediately.
declare -a results
any_failed=0

echo "=== Waiting for ${N} workers (logs: ${log_dir}/worker-*.log) ==="
echo "    Hint: tail -f ${log_dir}/worker-*.log"

# Poll until all workers complete or one fails
while true; do
    all_done=true
    for i in $(seq 0 $((N - 1))); do
        [[ -n "${results[$i]+set}" ]] && continue
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            wait "${pids[$i]}" && results[$i]=0 || results[$i]=$?
            if [[ "${results[$i]}" -ne 0 ]]; then
                any_failed=1
                echo "=== Worker ${i} FINISHED: FAILED (exit ${results[$i]}) ==="
            else
                echo "=== Worker ${i} FINISHED: PASSED ==="
            fi
        else
            all_done=false
        fi
    done
    ${all_done} && break
    # If a worker failed, kill the rest and stop waiting
    if [[ "$any_failed" -ne 0 ]]; then
        echo "=== A worker failed -- killing remaining workers ==="
        for i in $(seq 0 $((N - 1))); do
            [[ -n "${results[$i]+set}" ]] && continue
            pkill -P "${pids[$i]}" 2>/dev/null || true
            kill "${pids[$i]}" 2>/dev/null || true
            wait "${pids[$i]}" 2>/dev/null || true
            results[$i]=1
            echo "=== Worker ${i} KILLED ==="
        done
        break
    fi
    sleep 3
done

echo "=== All workers done ==="

# Worker output is redirected to per-worker files. Dump every failed or killed
# worker's output here so the invoking make process captures the diagnostics.
if [[ "$any_failed" -ne 0 ]]; then
    for i in $(seq 0 $((N - 1))); do
        [[ "${results[$i]}" -ne 0 ]] || continue
        echo "=== Worker ${i} output (exit ${results[$i]}): ${log_files[$i]} ==="
        if [[ -f "${log_files[$i]}" ]]; then
            cat "${log_files[$i]}"
        else
            echo "Worker ${i} log is missing: ${log_files[$i]}"
        fi
        echo "=== End worker ${i} output ==="
    done
fi

# Cleanup timeout (seconds) -- prevents infinite hangs on stuck finalizers
CLEANUP_TIMEOUT="${KUTTL_CLEANUP_TIMEOUT:-600}"

# Phase 1: remove CRs from all namespaces (operators stay running)
for i in $(seq 0 $((N - 1))); do
    ns="${worker_ns[$i]}"
    echo "=== Cleaning up CRs in namespace ${ns} ==="
    cleanup_env=(NAMESPACE="${ns}" CRC_STORAGE_NAMESPACE="${ns}" STORAGE_ID="worker-${i}")
    if [[ "${SERVICE}" == "openstack" ]]; then
        cleanup_env+=(STORAGE_CLASS="${worker_storage_class[$i]}")
    fi
    timeout "${CLEANUP_TIMEOUT}" env "${cleanup_env[@]}" make "${SERVICE}_kuttl_deploy_cleanup" || true
done

# Phase 2: full cleanup including operators (CR re-cleanup is idempotent)
echo "=== Final cleanup (including operators) ==="
for i in $(seq 0 $((N - 1))); do
    cleanup_env=(NAMESPACE="${worker_ns[$i]}" CRC_STORAGE_NAMESPACE="${worker_ns[$i]}" STORAGE_ID="worker-${i}")
    if [[ "${SERVICE}" == "openstack" ]]; then
        cleanup_env+=(STORAGE_CLASS="${worker_storage_class[$i]}")
    fi
    timeout "${CLEANUP_TIMEOUT}" env "${cleanup_env[@]}" make "${SERVICE}_kuttl_cleanup" || true
done

for i in $(seq 0 $((N - 1))); do
    if [[ -n "${worker_repo_dir[$i]:-}" ]]; then
        # KUTTL's vendored Kubernetes binaries in the copied repo are
        # read-only, so make the temporary tree removable by its owner.
        chmod -R u+w -- "${worker_repo_dir[$i]}" 2>/dev/null || true
        rm -rf -- "${worker_repo_dir[$i]}"
    fi
done

# Print summary
echo ""
echo "=== KUTTL Parallel Run Summary ==="
for i in $(seq 0 $((N - 1))); do
    status="PASS"
    if [[ "${results[$i]}" -ne 0 ]]; then
        status="FAIL (exit ${results[$i]})"
    fi
    echo "  Worker ${i} [${worker_ns[$i]}]: ${status}"
    echo "    Tests: ${worker_tests[$i]}"
done

if [[ "$any_failed" -ne 0 ]]; then
    echo ""
    echo "FAILED: one or more workers failed"
    exit 1
fi

echo ""
echo "All workers passed"
