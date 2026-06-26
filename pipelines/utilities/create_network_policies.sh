#!/bin/bash

set -x

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${SCRIPT_DIR}/longhorn_namespace.sh"

get_longhorn_manager_networkpolicy_path(){
  local policy_path="${SCRIPT_DIR}/../../manager/integration/deploy/network-policies/longhorn-manager-networkpolicy.yaml"
  if [[ ! -f "${policy_path}" ]]; then
    policy_path="${SCRIPT_DIR}/../../../manager/integration/deploy/network-policies/longhorn-manager-networkpolicy.yaml"
  fi

  if [[ ! -f "${policy_path}" ]]; then
    echo "Longhorn manager test NetworkPolicy manifest not found" >&2
    exit 1
  fi

  echo "${policy_path}"
}

longhorn_internal_networkpolicies_exist(){
  kubectl get networkpolicy longhorn-manager -n "${LONGHORN_NAMESPACE}" >/dev/null 2>&1 &&
    kubectl get networkpolicy instance-manager -n "${LONGHORN_NAMESPACE}" >/dev/null 2>&1
}

apply_longhorn_test_networkpolicy(){
  if ! command -v yq > /dev/null 2>&1; then
    echo "yq is required to install Longhorn test NetworkPolicies"
    exit 1
  fi

  local policy_path
  policy_path=$(get_longhorn_manager_networkpolicy_path) || exit 1

  LONGHORN_NAMESPACE="${LONGHORN_NAMESPACE}" yq e '.metadata.namespace = strenv(LONGHORN_NAMESPACE)' "${policy_path}" | kubectl apply -f -
}

delete_longhorn_manager_networkpolicy(){
  kubectl delete networkpolicy allow-longhorn-test-to-manager allow-longhorn-test-to-instance-manager -n "${LONGHORN_NAMESPACE}" --ignore-not-found=true
}

setup_longhorn_manager_networkpolicy(){
  get_longhorn_namespace

  if longhorn_internal_networkpolicies_exist; then
    apply_longhorn_test_networkpolicy
  else
    delete_longhorn_manager_networkpolicy
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if declare -f "$1" > /dev/null; then
    "$@"
  else
    echo "Function '$1' not found"
    exit 1
  fi
fi
