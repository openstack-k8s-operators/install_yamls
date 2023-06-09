set -ex

function extract_crds {
    local IN_DIR=$1
    local OUT_DIR=$2
    for X in $(file ${IN_DIR}/* | grep gzip | cut -f 1 -d ':'); do
        tar xvf $X -C ${OUT_DIR}/;
    done
}

mkdir -p ${OUT}/${OPENSTACK_CRDS_DIR}
mkdir -p ${OUT}/${OPENSTACK_CRDS_DIR}-source
#openstack-operator bundle
skopeo copy "docker://${OPENSTACK_BUNDLE_IMG}" dir:${OUT}/${OPENSTACK_CRDS_DIR}-source
extract_crds "${OUT}/${OPENSTACK_CRDS_DIR}-source" "${OUT}/${OPENSTACK_CRDS_DIR}"

# this downloads the pinned bundle images based on the go.mod file in openstack-operator
for BUNDLE in $(cd ${OPERATOR_BASE_DIR}/openstack-operator; bash hack/pin-bundle-images.sh | tr "," " "); do
    skopeo copy "docker://$BUNDLE" dir:${OUT}/${OPENSTACK_CRDS_DIR}-source;
    extract_crds "${OUT}/${OPENSTACK_CRDS_DIR}-source" "${OUT}/${OPENSTACK_CRDS_DIR}"
done

for CRD in $(grep -l CustomResourceDefinition ${OUT}/${OPENSTACK_CRDS_DIR}/manifests/*); do
    oc apply -f $CRD;
done
