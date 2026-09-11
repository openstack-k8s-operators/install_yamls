#!/bin/bash
# Fetch image digests for openstack-s2i-containers images using Quay.io API

set -euo pipefail

REGISTRY="quay.io/openstack-s2i-containers"
TAG="master-latest"
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

    local url="https://quay.io/api/v1/repository/openstack-s2i-containers/${repo_name}/tag/?specificTag=${tag_name}"
    local response=$(curl -s "$url" 2>/dev/null)

    if [ -z "$response" ]; then
        echo ""
        return 1
    fi

    # Extract manifest_digest from the JSON response
    local digest=$(echo "$response" | jq -r ".tags[] | select(.name==\"${tag_name}\") | .manifest_digest" 2>/dev/null | head -1)

    if [ -n "$digest" ] && [ "$digest" != "null" ]; then
        echo "$digest"
        return 0
    fi

    echo ""
    return 1
}

echo "Fetching image digests from ${REGISTRY} via API..."
echo ""

failed_count=0
success_count=0
failed_images=()

for img in "${images[@]}"; do
    img_name=$(convert_to_image_name "$img")

    echo -n "Fetching digest for ${img} -> ${img_name}... "

    digest=$(get_digest_via_api "$img_name" "$TAG")

    if [ -n "$digest" ] && [[ "$digest" =~ ^sha256: ]]; then
        IMAGE_DIGESTS["$img"]="${REGISTRY}/${img_name}@${digest}"
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

# Save digests to a file
DIGEST_FILE="/home/zuul/install_yamls/image-digests.env"
echo "# Image digests fetched on $(date)" > "$DIGEST_FILE"
echo "# Successfully fetched: ${success_count}, Failed: ${failed_count}" >> "$DIGEST_FILE"
for img in $(echo "${!IMAGE_DIGESTS[@]}" | tr ' ' '\n' | sort); do
    var_name=$(echo "$img" | tr '/' '_' | tr '-' '_' | tr '[:lower:]' '[:upper:]')
    echo "export IMAGE_${var_name}=\"${IMAGE_DIGESTS[$img]}\"" >> "$DIGEST_FILE"
done

echo "Digest environment variables saved to: $DIGEST_FILE"
echo ""

# Now generate the OpenStackVersion patch YAML
PATCH_FILE="${PATCH_FILE:-$PWD/patch-s2i-openstack-versions.yaml}"
echo "Generating OpenStackVersion patch file..."
echo "---" > "$PATCH_FILE"
echo "# OpenStackVersion customContainerImages patch" >> "$PATCH_FILE"
echo "# Generated on $(date)" >> "$PATCH_FILE"
echo "# Using images from ${REGISTRY} with tag ${TAG}" >> "$PATCH_FILE"
echo "# Successfully fetched: ${success_count}, Failed: ${failed_count}" >> "$PATCH_FILE"
echo "apiVersion: core.openstack.org/v1beta1" >> "$PATCH_FILE"
echo "kind: OpenStackVersion" >> "$PATCH_FILE"
echo "metadata:" >> "$PATCH_FILE"
echo "  name: openstack-galera-network-isolation" >> "$PATCH_FILE"
echo "  namespace: openstack" >> "$PATCH_FILE"
echo "spec:" >> "$PATCH_FILE"
echo "  customContainerImages:" >> "$PATCH_FILE"

# Build a sorted unique list of all field names
declare -A all_fields
for img in "${!IMAGE_DIGESTS[@]}"; do
    IFS=',' read -ra fields <<< "${IMAGE_TO_FIELDS[$img]}"
    for field in "${fields[@]}"; do
        all_fields["$field"]="${IMAGE_DIGESTS[$img]}"
    done
done

# Sort and output the fields
for field in $(echo "${!all_fields[@]}" | tr ' ' '\n' | sort); do
    echo "    ${field}: ${all_fields[$field]}" >> "$PATCH_FILE"
done

echo ""
echo "OpenStackVersion patch file created: $PATCH_FILE"
echo "  - Total fields: ${#all_fields[@]}"
# echo ""
# echo "To apply this patch, copy it to your deployment directory and run:"
# echo "  cp $PATCH_FILE out/openstack/cr/"
# echo "  make openstack_deploy"
# echo "OR"
echo "  oc apply -f $PATCH_FILE"
echo "  make openstack_deploy"
