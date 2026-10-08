#!/bin/bash
# Fetch image digests for openstack-s2i-containers images using Quay.io API

set -euo pipefail

REGISTRY=${REGISTRY:-quay.io/openstack-s2i-containers}
TAG=${TAG:-master-latest}
NAMESPACE=${NAMESPACE:-openstack}
OUTPUT_FORMAT=${OUTPUT_FORMAT:-patch}  # "patch" or "kustomize"
OUTPUT_FILE=${OUTPUT_FILE:-$PWD/${OUTPUT_FORMAT}-openstack-versions-${TAG}.yaml}

# Split REGISTRY into URL and ORG components
# If REGISTRY_URL or REGISTRY_ORG are explicitly set, use them; otherwise derive from REGISTRY
REGISTRY_URL=${REGISTRY_URL:-${REGISTRY%%/*}}
REGISTRY_ORG=${REGISTRY_ORG:-${REGISTRY#*/}}

MAPPINGS_FILE=$1

if [ ! -f "$MAPPINGS_FILE" ]; then
    echo "Error: image-mappings.yaml not found at $MAPPINGS_FILE"
    exit 1
fi

declare -A IMAGE_DIGESTS
declare -A IMAGE_TO_FIELDS

# Extract s2i build targets from image-mappings.yaml
echo "Reading image mappings from $MAPPINGS_FILE..."
mapfile -t images < <(yq eval '.openstack_version.custom_container_images | keys | .[]' "$MAPPINGS_FILE")

# Also build a mapping from image to field names
for img in "${images[@]}"; do
    fields=$(yq eval ".openstack_version.custom_container_images.\"${img}\" | .[]" "$MAPPINGS_FILE" | tr '\n' ',' | sed 's/,$//')
    IMAGE_TO_FIELDS["$img"]="$fields"
done

echo "Found ${#images[@]} images to process"
echo ""

# Function to convert s2i build target to quay.io image name
convert_to_image_name() {
    local target="$1"
    local img_name="${target#*/}"
    echo "openstack-${img_name}"
}

# Function to get digest via Quay.io API
get_digest_via_api() {
    local repo_name="$1"
    local tag_name="$2"

    local url="https://${REGISTRY_URL}/api/v1/repository/${REGISTRY_ORG}/${repo_name}/tag/?specificTag=${tag_name}"
    local response
    response=$(curl -s "$url" 2>/dev/null)

    if [ -z "$response" ]; then
        echo ""
        return 1
    fi

    # Extract manifest_digest from the JSON response
    local digest
    digest=$(echo "$response" | jq -r ".tags[] | select(.name==\"${tag_name}\") | .manifest_digest" 2>/dev/null | head -1)

    if [ -n "$digest" ] && [ "$digest" != "null" ]; then
        echo "$digest"
        return 0
    fi

    echo ""
    return 1
}

echo "Fetching image digests from ${REGISTRY_URL}/${REGISTRY_ORG} via API..."
echo ""

failed_count=0
success_count=0
failed_images=()

for img in "${images[@]}"; do
    img_name=$(convert_to_image_name "$img")

    echo -n "Fetching digest for ${img} -> ${img_name}... "

    digest=$(get_digest_via_api "$img_name" "$TAG")

    if [ -n "$digest" ] && [[ "$digest" =~ ^sha256: ]]; then
        IMAGE_DIGESTS["$img"]="${REGISTRY_URL}/${REGISTRY_ORG}/${img_name}@${digest}"
        echo "✓ ${digest}"
        success_count=$((success_count + 1))
    else
        echo "✗ FAILED"
        failed_count=$((failed_count + 1))
        failed_images+=("$img -> $img_name")
    fi

    # Small delay to avoid rate limiting
    sleep 0.2
done

echo ""
echo "Summary: ${success_count} succeeded, ${failed_count} failed"

if [ ${failed_count} -gt 0 ]; then
    echo ""
    echo "Failed images:"
    printf '  %s\n' "${failed_images[@]}"
fi

echo ""

if [ ${success_count} -eq 0 ]; then
    echo "ERROR: No images were successfully fetched!"
    exit 1
fi

# Build a sorted unique list of all field names
declare -A all_fields
for img in "${!IMAGE_DIGESTS[@]}"; do
    IFS=',' read -ra fields <<< "${IMAGE_TO_FIELDS[$img]}"
    for field in "${fields[@]}"; do
        all_fields["$field"]="${IMAGE_DIGESTS[$img]}"
    done
done

# Generate the patch content
PATCH_CONTENT=$(cat <<EOF
---
# OpenStackVersion customContainerImages patch
# Generated on $(date)
# Using images from ${REGISTRY_URL}/${REGISTRY_ORG} with tag ${TAG}
# Successfully fetched: ${success_count}, Failed: ${failed_count}
apiVersion: core.openstack.org/v1beta1
kind: OpenStackVersion
metadata:
  name: openstack-galera-network-isolation
  namespace: ${NAMESPACE}
spec:
  customContainerImages:
$(for field in $(echo "${!all_fields[@]}" | tr ' ' '\n' | sort); do
    echo "    ${field}: ${all_fields[$field]}"
done)
EOF
)

# Write output based on format
if [ "$OUTPUT_FORMAT" = "kustomize" ]; then
    echo "Generating kustomization file..."
    {
        echo "apiVersion: kustomize.config.k8s.io/v1beta1"
        echo "kind: Kustomization"
        echo ""
        echo "patchesStrategicMerge:"
        echo "  - |-"
        # Indent the patch content to match the kustomize inline patch format (4 spaces)
        echo "$PATCH_CONTENT" | sed 's/^/    /'
    } > "$OUTPUT_FILE"
else
    echo "Generating OpenStackVersion patch file..."
    echo "$PATCH_CONTENT" > "$OUTPUT_FILE"
fi

echo ""
if [ "$OUTPUT_FORMAT" = "kustomize" ]; then
    echo "Kustomization file created: $OUTPUT_FILE"
    echo "  - Total fields: ${#all_fields[@]}"
    echo ""
    echo "To use this kustomization:"
    echo "  Place it in your kustomize directory and reference it in your main kustomization.yaml"
else
    echo "OpenStackVersion patch file created: $OUTPUT_FILE"
    echo "  - Total fields: ${#all_fields[@]}"
    echo ""
    echo "To apply this patch:"
    echo "  oc apply -f $OUTPUT_FILE"
    echo "  make openstack_deploy"
fi
