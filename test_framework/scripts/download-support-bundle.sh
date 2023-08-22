#!/usr/bin/env bash

set -ex

SUPPORT_BUNDLE_FILE_NAME=${1:-"lh-support-bundle.zip"}
SUPPORT_BUNDLE_ISSUE_URL=${2:-""}
SUPPORT_BUNDLE_ISSUE_DESC=${3:-"Auto-generated support bundle"}

set_kubeconfig_envvar(){
    local ARCH=${1}
    local BASEDIR=${2}

    if [[ ${ARCH} == "amd64" ]] ; then
        if [[ ${TF_VAR_k8s_distro_name} == [rR][kK][eE] ]]; then
            export KUBECONFIG="${BASEDIR}/kube_config_rke.yml"
        elif [[ ${TF_VAR_k8s_distro_name} == [rR][kK][eE]2 ]]; then
            export KUBECONFIG="${BASEDIR}/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO}/rke2.yaml"
        elif [[ ${TF_VAR_k8s_distro_name} == "aks" ]]; then
            export KUBECONFIG="${BASEDIR}/aks.yml"
        elif [[ ${TF_VAR_k8s_distro_name} == "eks" ]]; then
            export KUBECONFIG="${BASEDIR}/eks.yml"
        else
            export KUBECONFIG="${BASEDIR}/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO}/k3s.yaml"
        fi
    elif [[ ${ARCH} == "arm64"  ]]; then
        if [[ ${TF_VAR_k8s_distro_name} == "aks" ]]; then
            export KUBECONFIG="${BASEDIR}/aks.yml"
        elif [[ ${TF_VAR_k8s_distro_name} == "eks" ]]; then
            export KUBECONFIG="${BASEDIR}/eks.yml"
        else
            export KUBECONFIG="${BASEDIR}/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO}/k3s.yaml"
        fi
    fi
}

set_kubeconfig_envvar ${TF_VAR_arch} ${TF_VAR_tf_workspace}

# get longhorn client api url
LH_CLIENT_URL=$(kubectl get svc -n longhorn-system longhorn-frontend -o json | jq -r '.spec.clusterIP + ":" + (.spec.ports[0].port|tostring)')

# create support bundle
JSON_PAYLOAD="{\"issueURL\": \"${SUPPORT_BUNDLE_ISSUE_DESC}\", \"description\": \"${SUPPORT_BUNDLE_ISSUE_DESC}\"}"
CURL_CMD="curl -s -XPOST http://${LH_CLIENT_URL}/v1/supportbundles -H 'Accept: application/json' -H 'Accept-Encoding: gzip, deflate' -d '"${JSON_PAYLOAD}"'"
CREATE_SUPPORT_BUNDLE_RESP=$(kubectl exec -n longhorn-system svc/longhorn-frontend -- bash -c "${CURL_CMD}")
echo "${CREATE_SUPPORT_BUNDLE_RESP}"
NODE_ID=$(${CREATE_SUPPORT_BUNDLE_RESP} | jq -r '.id')
NAME=$(${CREATE_SUPPORT_BUNDLE_RESP} | jq -r '.name')

# wait for support bundle url available
SUPPORT_BUNDLE_URL_READY=false
CURL_CMD="curl -s -GET http://${LH_CLIENT_URL}/v1/supportbundles/${NODE_ID}/${NAME} -H 'Accept: application/json' -H 'Accept-Encoding: gzip, deflate'"
while [[ ${SUPPORT_BUNDLE_URL_READY} == false ]]; do
    GET_SUPPORT_BUNDLE_RESP=$(kubectl exec -n longhorn-system svc/longhorn-frontend -- bash -c "${CURL_CMD}")
    echo "${GET_SUPPORT_BUNDLE_RESP}"
    SUPPORT_BUNDLE_URL=$(${GET_SUPPORT_BUNDLE_RESP} | jq -r '.links.self + "/" + .name')
    if [[ -n ${SUPPORT_BUNDLE_URL} ]]; then SUPPORT_BUNDLE_URL_READY=true; fi
done

SUPPORT_BUNDLE_READY=false
while [[ ${SUPPORT_BUNDLE_READY} == false ]]; do
    CMD_RESULT=$(kubectl exec -n longhorn-system svc/longhorn-frontend -- curl -s -H 'Accept: application/json' "${SUPPORT_BUNDLE_URL}")
    PERCENT=$(echo "${CMD_RESULT}" | jq -r '.progressPercentage' || true)
    echo "${PERCENT}"

    if [[ ${PERCENT} == 100 ]]; then SUPPORT_BUNDLE_READY=true; fi
done

kubectl exec -n longhorn-system svc/longhorn-frontend -- curl -s -H 'Accept-Encoding: gzip, deflate' "${SUPPORT_BUNDLE_URL}/download" > "${SUPPORT_BUNDLE_FILE_NAME}"