#!/bin/bash
# set -x
NAMESPACE=$1
OPERATOR_NAME=$2
IMAGE=$3
if [ -z "${NAMESPACE}" ]; then
  echo "Please set NAMESPACE as ARG1"; exit 1
fi
if [ -z "${OPERATOR_NAME}" ]; then
  echo "Please set OPERATOR_NAME as ARG2"; exit 1
fi
if [ -z "${IMAGE}" ]; then
  echo "Please set IMAGE as ARG3"; exit 1
fi

OPERATOR_DIR=out/${NAMESPACE}/${OPERATOR_NAME}

if [ ! -d ${OPERATOR_DIR} ]; then
  mkdir -p ${OPERATOR_DIR}
fi

# can share this for all the operators, won't get re-applied if it already exists
cat > ${OPERATOR_DIR}/operatorgroup.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openstack
  namespace: ${NAMESPACE}
spec:
  targetNamespaces:
  - ${NAMESPACE}
EOF_CAT

cat > ${OPERATOR_DIR}/catalogsource.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: $OPERATOR_NAME-operator-index
  namespace: ${NAMESPACE}
spec:
  image: ${IMAGE}
  sourceType: grpc
EOF_CAT

cat > ${OPERATOR_DIR}/subscription.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${OPERATOR_NAME}-operator
  namespace: ${NAMESPACE}
spec:
  name: ${OPERATOR_NAME}-operator
  channel: alpha
  config:
    env:
    - name: WATCH_NAMESPACE
      value: ${NAMESPACE}
  source: ${OPERATOR_NAME}-operator-index
  sourceNamespace: ${NAMESPACE}
EOF_CAT
