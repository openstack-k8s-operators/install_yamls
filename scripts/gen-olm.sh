#!/bin/bash

OPERATOR_NAME=$1
IMAGE=$2
if [ -z "$OPERATOR_NAME" ]; then
  echo "Please set OPERATOR_NAME as ARG1"; exit 1
fi
if [ -z "$IMAGE" ]; then
  echo "Please set IMAGE as ARG2"; exit 1
fi

if [ ! -d out/$OPERATOR_NAME ]; then
  mkdir -p out/$OPERATOR_NAME
fi

# can share this for all the operators, won't get re-applied if it already exists
cat > out/$OPERATOR_NAME/operatorgroup.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openstack
  namespace: openstack
spec:
  targetNamespaces:
  - openstack
EOF_CAT

cat > out/$OPERATOR_NAME/catalogsource.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: $OPERATOR_NAME-operator-index
  namespace: openstack
spec:
  image: $IMAGE
  sourceType: grpc
EOF_CAT

cat > out/$OPERATOR_NAME/subscription.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: $OPERATOR_NAME-operator
  namespace: openstack
spec:
  name: $OPERATOR_NAME-operator
  channel: alpha
  config:
    env:
    - name: WATCH_NAMESPACE
      value: openstack
  source: $OPERATOR_NAME-operator-index
  sourceNamespace: openstack
EOF_CAT
