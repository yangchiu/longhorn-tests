set_kubeconfig(){
  # rke2, rke and k3s all support amd64
  # but only k3s supports arm64
  if [[ "${DISTRO}" == "talos" ]]; then
    export KUBECONFIG="${PWD}/test_framework/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO}/kubeconfig"
    until [ $(kubectl get node -o jsonpath='{.items[*].status.conditions}'  | jq '.[] | select(.type  == "Ready").status' | grep -ci true) -eq 4 ]; do
      echo "waiting for talos cluster nodes to be running";
      sleep 30;
    done
  elif [[ "${LONGHORN_TEST_CLOUDPROVIDER}" == "harvester" ]]; then
    export KUBECONFIG="${PWD}/test_framework/kube_config.yaml"
  elif [[ ${TF_VAR_k8s_distro_name} == "aks" ]]; then
    export KUBECONFIG="${PWD}/test_framework/aks.yml"
  elif [[ ${TF_VAR_k8s_distro_name} == "eks" ]]; then
    export KUBECONFIG="${PWD}/test_framework/eks.yml"
  elif [[ "${TF_VAR_arch}" == "amd64" ]]; then
    if [[ "${TF_VAR_k8s_distro_name}" == "rke" ]]; then
        export KUBECONFIG="${PWD}/test_framework/kube_config_rke.yml"
    elif [[ "${TF_VAR_k8s_distro_name}" == "rke2" ]]; then
        export KUBECONFIG="${PWD}/test_framework/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO}/rke2.yaml"
    else
        export KUBECONFIG="${PWD}/test_framework/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO}/k3s.yaml"
    fi
  elif [[ "${TF_VAR_arch}" == "arm64"  ]]; then
    export KUBECONFIG="${PWD}/test_framework/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO}/k3s.yaml"
  fi
}

wait_for_k8s_api_server_stable(){
  stable_count=0
  while true; do
    result=$(kubectl get --raw /healthz)
    if [[ "$result" == "ok" ]]; then
      stable_count=$((stable_count + 1))
      if [[ $stable_count -ge 10 ]]; then
        echo "K8s API server is stable!"
        break
      fi
    else
      echo "K8s API server unhealthy: $result"
      stable_count=0
    fi
    sleep 10
  done
}
