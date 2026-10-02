#!/bin/bash
set -euo pipefail

# Configuration environment variables:
#   NAMESPACE             - namespace for the OpenStackAssistant CR (default: openstack)
#   LIGHTSPEED_NAMESPACE  - namespace where lightspeed-stack runs (default: openstack-lightspeed)
#   LIGHTSPEED_URL        - Lightspeed API base URL (default: in-cluster service URL)
#   CONTAINER_IMAGE       - assistant container image
#   ASSISTANT_NAME        - name for the CR and related resources
#   MODEL                 - model override (empty = auto-discover first LLM)
#   OPENSTACK_CLIENT_NAME - OpenStackClient providing the MCP endpoint
#   PVC_NAME              - existing or new PVC for persistent assistant state
#   PVC_SIZE              - requested size when creating the PVC (default: 1Gi)
#   PVC_STORAGE_CLASS     - storage class when creating the PVC (empty = default)

NAMESPACE="${NAMESPACE:-openstack}"
LIGHTSPEED_NAMESPACE="${LIGHTSPEED_NAMESPACE:-openstack-lightspeed}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-quay.io/openstack-s2i-containers/openstack-goose:master-latest}"
ASSISTANT_NAME="${ASSISTANT_NAME:-openstack-assistant}"
MODEL="${MODEL:-}"
OPENSTACK_CLIENT_NAME="${OPENSTACK_CLIENT_NAME:-openstackclient}"
PVC_NAME="${PVC_NAME:-${ASSISTANT_NAME}-home}"
PVC_SIZE="${PVC_SIZE:-1Gi}"
PVC_STORAGE_CLASS="${PVC_STORAGE_CLASS:-}"

echo "=== Create OpenStackAssistant ==="

# --- Step 1: Discover models from LSCORE config ---
echo "Discovering models from ogx-config in namespace '${LIGHTSPEED_NAMESPACE}'..."

RUN_YAML=$(oc get configmap ogx-config -n "${LIGHTSPEED_NAMESPACE}" \
  -o jsonpath='{.data.ogx_config\.yaml}')

if [ -z "${RUN_YAML}" ]; then
  echo "ERROR: Could not read ogx-config ConfigMap"
  exit 1
fi

# Extract LLM models: provider_id and model_id pairs
# Parse the YAML to find model entries with model_type: llm.
MODELS_JSON=$(echo "${RUN_YAML}" | python3 -c "
import sys, json, yaml
data = yaml.safe_load(sys.stdin)
models = [
    {'provider_id': m['provider_id'], 'model_id': m['model_id']}
    for m in data.get('registered_resources', {}).get('models', [])
    if m.get('model_type') == 'llm'
]
print(json.dumps(models))
")

MODEL_COUNT=$(echo "${MODELS_JSON}" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

if [ "${MODEL_COUNT}" -eq 0 ]; then
  echo "ERROR: No LLM models found in ogx-config"
  exit 1
fi

echo "Available LLM models:"
echo "${MODELS_JSON}" | python3 -c "
import sys, json
for m in json.load(sys.stdin):
    print(f\"  - {m['provider_id']}/{m['model_id']}\")
"

# Select model
if [ -z "${MODEL}" ]; then
  SELECTED_MODEL=$(echo "${MODELS_JSON}" | python3 -c "
import sys, json
m = json.load(sys.stdin)[0]
print(f\"{m['provider_id']}/{m['model_id']}\")
")
  echo "Auto-selected first model: ${SELECTED_MODEL}"
else
  SELECTED_MODEL="${MODEL}"
  echo "Using specified model: ${SELECTED_MODEL}"
fi

# --- Step 2: Build lightspeed-stack service URL ---
LIGHTSPEED_URL="${LIGHTSPEED_URL:-https://lightspeed-app-server.${LIGHTSPEED_NAMESPACE}.svc:8443/v1}"
echo "Lightspeed URL: ${LIGHTSPEED_URL}"

READY_ENDPOINTS=$(oc get endpoints lightspeed-app-server -n "${LIGHTSPEED_NAMESPACE}" \
  -o jsonpath='{.subsets[*].addresses}' 2>/dev/null)
if [ -z "${READY_ENDPOINTS}" ]; then
  echo "ERROR: lightspeed-app-server in namespace '${LIGHTSPEED_NAMESPACE}' has no ready endpoints."
  echo "Check 'oc get openstacklightspeed -n ${LIGHTSPEED_NAMESPACE}' and 'oc get pods -n ${LIGHTSPEED_NAMESPACE}' before retrying."
  exit 1
fi

# --- Step 3: Verify the OpenStack MCP endpoint source ---
echo "Checking OpenStackClient '${OPENSTACK_CLIENT_NAME}' in namespace '${NAMESPACE}'..."

if ! oc get openstackclient.client.openstack.org "${OPENSTACK_CLIENT_NAME}" \
  -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: OpenStackClient '${OPENSTACK_CLIENT_NAME}' was not found in namespace '${NAMESPACE}'."
  exit 1
fi

MCP_ENABLED=$(oc get openstackclient.client.openstack.org "${OPENSTACK_CLIENT_NAME}" \
  -n "${NAMESPACE}" -o jsonpath='{.spec.mcp.enabled}')
if [ "${MCP_ENABLED}" != "true" ]; then
  CONTROL_PLANE_NAME=$(oc get openstackclient.client.openstack.org "${OPENSTACK_CLIENT_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.metadata.ownerReferences[?(@.kind=="OpenStackControlPlane")].name}')

  if [ -z "${CONTROL_PLANE_NAME}" ]; then
    echo "ERROR: OpenStackClient '${OPENSTACK_CLIENT_NAME}' is not owned by an OpenStackControlPlane."
    echo "MCP cannot be enabled through the OpenStackControlPlane template."
    exit 1
  fi

  echo "MCP is not enabled; enabling it in OpenStackControlPlane '${CONTROL_PLANE_NAME}'..."
  oc patch openstackcontrolplane.core.openstack.org "${CONTROL_PLANE_NAME}" \
    -n "${NAMESPACE}" --type=merge \
    -p '{"spec":{"openstackclient":{"template":{"mcp":{"enabled":true}}}}}'

  echo "Waiting for OpenStackClient '${OPENSTACK_CLIENT_NAME}' to enable MCP..."
  oc wait openstackclient.client.openstack.org "${OPENSTACK_CLIENT_NAME}" \
    -n "${NAMESPACE}" --for=jsonpath='{.spec.mcp.enabled}'=true --timeout=120s
fi

# --- Step 4: Create or reuse persistent storage ---
if oc get persistentvolumeclaim "${PVC_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "Using existing PVC '${PVC_NAME}' in namespace '${NAMESPACE}'..."
else
  echo "Creating PVC '${PVC_NAME}' in namespace '${NAMESPACE}'..."

  STORAGE_CLASS_FIELD=""
  if [ -n "${PVC_STORAGE_CLASS}" ]; then
    STORAGE_CLASS_FIELD="  storageClassName: ${PVC_STORAGE_CLASS}"
  fi

  oc apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${ASSISTANT_NAME}
spec:
  accessModes:
    - ReadWriteOnce
${STORAGE_CLASS_FIELD}
  resources:
    requests:
      storage: ${PVC_SIZE}
EOF
fi

# --- Step 5: Create hints ConfigMap ---
echo "Creating hints ConfigMap '${ASSISTANT_NAME}-hints' in namespace '${NAMESPACE}'..."

oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ASSISTANT_NAME}-hints
  namespace: ${NAMESPACE}
  labels:
    app: ${ASSISTANT_NAME}
data:
  hints: |
    This is an OpenStack deployment project running on an OpenShift cluster.

    ## Environment
    - Use \`oc\` (OpenShift CLI) for cluster commands instead of \`kubectl\`

    ## Important
    - Only use 'oc' (similar to 'kubectl') commands which *read* data. Do not edit or patch resources.

    ## Recipes
    Custom slash commands are available. Type \`/cluster-health\` to run a cluster health check.

    ## Context Management
    - Keep command outputs short. Use --no-headers, field selectors, and | head/tail to limit output.
    - Summarize each command output immediately before running the next command.
    - Do not store raw command output in memory; only retain the summary.
EOF

# --- Step 6: Create recipes ConfigMap ---
echo "Creating recipes ConfigMap '${ASSISTANT_NAME}-recipes' in namespace '${NAMESPACE}'..."

oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ASSISTANT_NAME}-recipes
  namespace: ${NAMESPACE}
  labels:
    app: ${ASSISTANT_NAME}
data:
  cluster-health.yaml: |
    version: "1.0.0"
    title: Cluster Health Status Check
    description: Run a full cluster health check using subagents for OpenShift and OpenStack categories, then output a combined markdown report
    prompt: |
      Run a cluster health check using two summon subagents, then immediately output the final report. Do not launch any additional subagents beyond the two described below.

      Use summon to create these two subagents:

      Subagent 1 - "OpenShift Health": Run each command and summarize the output before moving on:
      - \`oc get nodes -o wide\` - note node count, roles, and any NotReady nodes.
      - \`oc get clusteroperators\` and \`oc get clusterversion\` - note any degraded or unavailable operators.
      - \`oc get pv\` - note any volumes that are not Bound.
      - \`oc get nncp\` - note any degradations.
      - \`oc get events --all-namespaces --sort-by='.lastTimestamp' --field-selector type=Warning | tail -20\` - summarize recent warnings.
      Return a markdown section titled \`## OpenShift Health\` with findings.

      Subagent 2 - "OpenStack Health": Run each command and summarize the output before moving on:
      - \`oc get openstackcontrolplane -n openstack -o wide\` - summarize the control plane status.
      - \`oc get pods -n openstack --field-selector=status.phase!=Running,status.phase!=Succeeded\` - note any unhealthy pods.
      Return a markdown section titled \`## OpenStack Health\` with findings.

      Once both subagents return their results, immediately output a final markdown report containing:
      - \`# Cluster Health Status Report\`
      - A timestamp
      - The \`## OpenShift Health\` section from subagent 1
      - The \`## OpenStack Health\` section from subagent 2
      - A \`## Summary\` section with an overall assessment (Healthy / Degraded / Critical) and brief explanation of any issues.

      After outputting the report, you are done. Do not run any more commands or subagents.
EOF

# --- Step 7: Create Goose configuration overlay ConfigMap ---
echo "Creating Goose configuration ConfigMap '${ASSISTANT_NAME}-goose-config' in namespace '${NAMESPACE}'..."

oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ASSISTANT_NAME}-goose-config
  namespace: ${NAMESPACE}
  labels:
    app: ${ASSISTANT_NAME}
data:
  config.yaml: |
    extensions:
      summon:
        enabled: true
      todo:
        enabled: true
EOF

# --- Step 8: Create OpenStackAssistant CR ---
echo "Creating OpenStackAssistant '${ASSISTANT_NAME}' in namespace '${NAMESPACE}'..."

oc apply -f - <<EOF
apiVersion: assistant.openstack.org/v1beta1
kind: OpenStackAssistant
metadata:
  name: ${ASSISTANT_NAME}
  namespace: ${NAMESPACE}
spec:
  containerImage: ${CONTAINER_IMAGE}
  lightspeedStack:
    baseURL: ${LIGHTSPEED_URL}
    model: ${SELECTED_MODEL}
  mcpServers:
    - name: openstack
      openstackClientRef: ${OPENSTACK_CLIENT_NAME}
  storage:
    pvcName: ${PVC_NAME}
  extraConfig:
    - name: ${ASSISTANT_NAME}-hints
      mountPath: /etc/openstack-goose/hints
    - name: ${ASSISTANT_NAME}-recipes
      mountPath: /etc/openstack-goose/recipes
    - name: ${ASSISTANT_NAME}-goose-config
      mountPath: /etc/openstack-goose/config-overlay
EOF

# --- Step 9: Wait and verify ---
echo "Waiting for OpenStackAssistant to be ready..."
oc wait openstackassistant.assistant.openstack.org "${ASSISTANT_NAME}" -n "${NAMESPACE}" \
  --for=condition=Ready --timeout=120s 2>/dev/null || true

echo ""
echo "=== OpenStackAssistant Status ==="
oc get openstackassistant.assistant.openstack.org "${ASSISTANT_NAME}" -n "${NAMESPACE}" 2>/dev/null || echo "CR created but status not yet available"
echo ""
echo "=== Created/Modified Resources ==="
echo "  PVC:                  ${PVC_NAME} (namespace: ${NAMESPACE})"
echo "  ConfigMap:            ${ASSISTANT_NAME}-hints (namespace: ${NAMESPACE})"
echo "  ConfigMap:            ${ASSISTANT_NAME}-recipes (namespace: ${NAMESPACE})"
echo "  ConfigMap:            ${ASSISTANT_NAME}-goose-config (namespace: ${NAMESPACE})"
echo "  CR:                   openstackassistant/${ASSISTANT_NAME} (namespace: ${NAMESPACE})"
echo "  Model:                ${SELECTED_MODEL}"
echo "  Provider:             lightspeed (${LIGHTSPEED_URL})"
echo "  OpenStack MCP:        ${OPENSTACK_CLIENT_NAME}"
echo ""
echo "Done."
