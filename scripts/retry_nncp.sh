#!/bin/bash

set -euo pipefail
#set -x

MAX_RETRIES=${1:-5}
NNCP_INTERFACE=${INTERFACE:-enp6s0}
NNCP_TIMEOUT=${TIMEOUT:-240s}
NNCP_CLEANUP_TIMEOUT=${CLEANUP_TIMEOUT:-120s}
NNCP_NO_RESPONSE_MAX=${NO_RESPONSE_MAX:-120}
DEPLOY_DIR=${DEPLOY_DIR:-out/openstack/nncp/cr}
NNCP_MAX_ATTEMPTS=${NNCP_MAX_ATTEMPTS:-300}
CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD:-"rm -Rf"}

nncp_dns() {
    local attempts=0
    local max_attempts=15
    local nncp_status=""

    echo "nncp_dns: START"

    make nncp_generate

    if [ ! -f  ${DEPLOY_DIR}/crc_nncp_dns.yaml ]; then
        echo "nncp_dns: FATAL: could not find "${DEPLOY_DIR}/crc_nncp_dns.yaml
        exit 1
    fi

    # Apply NNCP config
    oc apply -f ${DEPLOY_DIR}/crc_nncp_dns.yaml

    # Wait for the NNCP to be marked as SuccessfullyConfigured
    if ! timeout "$NNCP_TIMEOUT" bash -c \
        "while ! oc wait nncp -l osp/interface=nncp-dns --for=jsonpath='{.status.conditions[0].reason}'=SuccessfullyConfigured --timeout=10s; do sleep 10; done"; then
        echo "ERROR: Timeout waiting for NNCP to be SuccessfullyConfigured" >&2
        return 1
    fi

    # a dummy wait loop for 15+ seconds after the successful configuration
    # most likely not necessary - leaving it for now
    while [ $attempts -lt $max_attempts ]; do
#       nncp_status=$(oc get nncp -l osp/interface=nncp-dns)
        nncp_status=$(oc get nncp -l osp/interface=nncp-dns -o jsonpath='{.items[0].status.conditions[0].reason}' 2>/dev/null || true)
        echo "nncp_dns: nncp_status = $nncp_status"

        if [[ ! "$nncp_status" == "SuccessfullyConfigured" ]]; then
            echo "nncp_dns: FAILED, do another nncp_with_retries"
            return 1
        fi

        attempts=$((attempts+1))
        sleep 1
    done

    oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/crc_nncp_dns.yaml

    # a dummy wait loop for 15+ seconds after the delete
    # most likely not necessary - leaving it for now
    attempts=1
    max_attempts=15

    while [ $attempts -lt $max_attempts ]; do
        nncp_status=$(oc get nncp -l osp/interface=nncp-dns)
        echo "nncp_dns: nncp_status = "${nncp_status}
        attempts=$((attempts+1))
        sleep 1
    done

    echo "nncp_dns: DONE"
    return 0
}

nncp()
{
    local attempts=0
    local no_response=0
    local no_response_max=${NNCP_NO_RESPONSE_MAX}
    local max_attempts=${NNCP_MAX_ATTEMPTS}
    local nncp_status=""

    echo "nncp: START"

    make nncp_generate

    if [ ! -f  ${DEPLOY_DIR}/crc_nncp.yaml ]; then
        echo "nncp: FATAL: could not find "${DEPLOY_DIR}/crc_nncp.yaml
        exit 1
    fi

    oc apply -f ${DEPLOY_DIR}/crc_nncp.yaml

    while [ $attempts -lt $max_attempts ]; do
        nncp_status=$(oc get nncp -l osp/interface=${NNCP_INTERFACE})
        echo "nncp: nncp_status = "${nncp_status}

        if [[ -z "$nncp_status" ]]; then
            echo "nncp: ERROR: nncp_status is empty"
            attempts=$((attempts+1))

            no_response=$((no_response+1))

            if [ $no_response -eq $no_response_max ]; then
                echo "nncp: FATAL: we have not received a response from the CRC after $no_response attempts, aborting!!!"
                exit 1
            fi

            sleep 1
            continue
        fi

        # if we are coming out of a non responsive CRC - best to delete, re-apply, and keep attempting
        if [[ $no_response -ne 0 ]]; then
            echo "nncp: CRC back to being responsive - best to delete, re-apply, and continue.."

            oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/crc_nncp.yaml
            # re-apply and continue
            oc apply -f ${DEPLOY_DIR}/crc_nncp.yaml
            no_response=0
            continue
        fi


        if echo "$nncp_status" | grep -q "No resources found"; then
            echo "nncp: REASON: No NNCP resource found yet"
            attempts=$((attempts+1))
            sleep 1
            continue
        fi

        if echo "$nncp_status" | grep -q "SuccessfullyConfigured"; then
            echo "nncp: REASON: SuccessfullyConfigured"
            echo "nncp: attempts= $attempts"
            break
        elif echo "$nncp_status" | grep -q "FailedToConfigure"; then
            echo "nncp: REASON: FailedToConfigure"
            oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/crc_nncp.yaml
            # re-apply and continue
            oc apply -f ${DEPLOY_DIR}/crc_nncp.yaml
            continue
        elif echo "$nncp_status" | grep -q "ConfigurationProgressingo"; then
            echo "nncp: REASON: ConfigurationProgressing"
            attempts=$((attempts+1))
            sleep 1
            continue
        elif [[ "$nncp_status" == "NAME         STATUS   REASON" ]]; then
            echo "nncp: REASON: NOT YET STARTED"
        else
            echo "nncp: WAITING for status to change: status = $nncp_status"
        fi

        attempts=$((attempts+1))
        echo "CONTINUING: attempts = $attempts"
        sleep 1
    done

    echo "nncp: DONE"

    if [ $attempts -eq $max_attempts ]; then
        echo "nncp: FAILED: hit maximum attempts ($attempts) - give another retry.."
        return 1
    fi

    return 0
}

nncp_cleanup()
{
    local attempts=0
    local max_attempts=${NNCP_MAX_ATTEMPTS}
    local no_response=0
    local no_response_max=${NNCP_NO_RESPONSE_MAX}
    local nncp_status=""

    echo "nncp_cleanup: START"

    make nncp_generate

    # not sure if this the best policy - force a delete in case there was a previous one running?
    # +++owen - commenting out for now - may need to check to see if it is active before deleting it?
    # oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/crc_nncp.yaml

    sed -i 's/state: up/state: absent/' ${DEPLOY_DIR}/crc_nncp.yaml
    oc apply -f ${DEPLOY_DIR}/crc_nncp.yaml

    while [ $attempts -lt $max_attempts ]; do
        nncp_status=$(oc get nncp -l osp/interface=${NNCP_INTERFACE})
        echo "nncp_cleanup: nncp_status = "${nncp_status}

        if [[ -z "$nncp_status" ]]; then
            echo "nncp: ERROR: nncp_status is empty"
            attempts=$((attempts+1))

            no_response=$((no_response+1))

            if [ $no_response -eq $no_response_max ]; then
                echo "nncp: FATAL: we have not received a response from the CRC after $no_response attempts, aborting!!!"
                exit 1
            fi

            sleep 1
            continue
        fi

        # if we are coming out of a non responsive CRC - best to delete, re-apply, and keep attempting
        if [[ $no_response -ne 0 ]]; then
            echo "nncp_cleanup: CRC back to being responsive - best to delete, re-apply, and continue.."

            oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/crc_nncp.yaml
            # re-apply and continue
            oc apply -f ${DEPLOY_DIR}/crc_nncp.yaml
            no_response=0
            continue
        fi

        no_response=0

        if echo "$nncp_status" | grep -q "No resources found"; then
            echo "nncp_cleanup: REASON: No NNCP resource found yet"
            attempts=$((attempts+1))
            sleep 1
            continue
        fi

        if echo "$nncp_status" | grep -q "SuccessfullyConfigured"; then
            echo "nncp_cleanup: REASON: SuccessfullyConfigured"
            break
        elif echo "$nncp_status" | grep -q "FailedToConfigure"; then
            echo "nncp_cleanup: REASON: FailedToConfigure"
            break;
        elif echo "$nncp_status" | grep -q "ConfigurationProgressing"; then
            echo "nncp_cleanup: REASON: ConfigurationProgressing"
            echo "nncp_cleanup: attempts= $attempts"
            attempts=$((attempts+1))
            sleep 1
            continue
        elif [[ "$nncp_status" == "NAME         STATUS   REASON" ]]; then
            echo "nncp_cleanup: REASON: NOT YET STARTED"
        else
            echo "nncp_cleanup: WAITING for status to change: status = $nncp_status"
        fi

        attempts=$((attempts+1))
        echo "CONTINUING: attempts = $attempts"
        sleep 1
    done


    echo "nncp_cleanup: DONE"

    if [ $attempts -eq $max_attempts ]; then
        echo "nncp_cleanup: FAILED: hit maximum attempts ($attempts) - give another retry.."
        return 1
    fi

    oc delete --ignore-not-found=true -f ${DEPLOY_DIR}/crc_nncp.yaml
   ${CLEANUP_DIR_CMD} ${DEPLOY_DIR}

    return 0
}

if [ -n "${1:-}" ]; then
    $1
    exit 0
fi

# Check if retries are needed
nncp_status=$(oc get nncp -l osp/interface=${NNCP_INTERFACE})
if echo "$nncp_status" | grep -q "SuccessfullyConfigured"; then \
    echo "nncp_with_retries: INFO: interface=${NNCP_INTERFACE} already configured, no need to retry"; \
    exit 0
fi

if ! nncp_dns; then
    echo "FATAL ERROR: could not plumb the NNCP DNS properly, aborting!!!"
    exit 1
fi

# Retry loop
retry=0
while (( retry < MAX_RETRIES )); do

    retry=$((retry+1))
    echo "retry: going on $retry/$MAX_RETRIES..."

    if nncp; then
        echo "DONE: nncp_retries successful after $retry/$MAX_RETRIES"
        exit 0
    fi

    make nncp_generate
    nncp_cleanup

    echo "retry: $retry/$MAX_RETRIES failed. Retrying in 1s..."
    sleep 1
done

echo "ERROR: Failed to run nncp after $MAX_RETRIES attempts. Aborting." >&2
exit 1
