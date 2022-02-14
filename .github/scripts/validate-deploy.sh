#!/usr/bin/env bash

GIT_REPO=$(cat git_repo)
GIT_TOKEN=$(cat git_token)

export KUBECONFIG=$(cat .kubeconfig)
NAMESPACE=$(cat .namespace)
COMPONENT_NAME=$(jq -r '.name // "my-module"' gitops-output.json)
SUBSCRIPTION_NAME=$(jq -r '.sub_name // "sub_name"' gitops-output.json)
OPERATOR_NAMESPACE=$(jq -r '.operator_namespace // "operator_namespace"' gitops-output.json)
CPD_NAMESPACE=$(jq -r '.cpd_namespace // "cpd_namespace"' gitops-output.json)
BRANCH=$(jq -r '.branch // "main"' gitops-output.json)
SERVER_NAME=$(jq -r '.server_name // "default"' gitops-output.json)
LAYER=$(jq -r '.layer_dir // "2-services"' gitops-output.json)
TYPE=$(jq -r '.type // "base"' gitops-output.json)

mkdir -p .testrepo

git clone https://${GIT_TOKEN}@${GIT_REPO} .testrepo

cd .testrepo || exit 1

find . -name "*"

if [[ ! -f "argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml" ]]; then
  echo "ArgoCD config missing - argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml"
  exit 1
fi

echo "Printing argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml"
cat "argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml"

if [[ ! -f "payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml" ]]; then
  echo "Application values not found - payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml"
  exit 1
fi

echo "Printing payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml"
cat "payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml"

count=0
until kubectl get namespace "${NAMESPACE}" 1>/dev/null 2>/dev/null || [[ $count -eq 20 ]]; do
  echo "Waiting for namespace: ${NAMESPACE}"
  count=$((count + 1))
  sleep 15
done

if [[ $count -eq 20 ]]; then
  echo "Timed out waiting for namespace: ${NAMESPACE}"
  exit 1
else
  echo "Found namespace: ${NAMESPACE}. Sleeping for 30 seconds to wait for everything to settle down"
  sleep 30
fi

echo "OPERATOR_NAMESPACE ***** "${OPERATOR_NAMESPACE}""
echo "SUBSCRIPTION_NAME *****"${SUBSCRIPTION_NAME}""
sleep 15

CSV=$(kubectl get sub -n "${OPERATOR_NAMESPACE}" "${SUBSCRIPTION_NAME}" -o jsonpath='{.status.installedCSV} {"\n"}')
SUB_STATUS=0
while [ $SUB_STATUS != 1 ]; do
  sleep 15
  SUB_STATUS=$(kubectl get deployments -n "${OPERATOR_NAMESPACE}" -l olm.owner="${CSV}" -o jsonpath="{.items[0].status.availableReplicas} {'\n'}")
  echo "Waiting for subscription/${SUBSCRIPTION_NAME} in ${OPERATOR_NAMESPACE}"
done

echo "CPD_NAMESPACE *****"${CPD_NAMESPACE}""
sleep 30
INST_STATUS=$(kubectl get WS ws-cr -n "${CPD_NAMESPACE}" -o jsonpath='{.status.wsStatus} {"\n"}')
echo "Watson Studio WS/ws-cr is ${INST_STATUS}"

cd ..
rm -rf .testrepo
