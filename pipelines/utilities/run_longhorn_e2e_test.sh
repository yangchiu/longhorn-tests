run_longhorn_e2e_test(){

  LONGHORN_TESTS_CUSTOM_IMAGE=${LONGHORN_TESTS_CUSTOM_IMAGE:-"longhornio/longhorn-e2e-test:master-head"}

  LONGHORN_TESTS_MANIFEST_FILE_PATH="e2e/deploy/test.yaml"

  if [[ -n ${PYTEST_CUSTOM_OPTIONS} ]]; then
    PYTEST_CUSTOM_OPTIONS=(${PYTEST_CUSTOM_OPTIONS})
    for OPT in "${PYTEST_CUSTOM_OPTIONS[@]}"; do
      PYTEST_COMMAND_ARGS='"'${OPT}'"'
    done
  fi

  ## generate test pod manifest
  yq e -i 'select(.spec.containers[0] != null).spec.containers[0].args=['"${PYTEST_COMMAND_ARGS}"']' "${LONGHORN_TESTS_MANIFEST_FILE_PATH}"
  yq e -i 'select(.spec.containers[0] != null).spec.containers[0].image="'${LONGHORN_TESTS_CUSTOM_IMAGE}'"' ${LONGHORN_TESTS_MANIFEST_FILE_PATH}

  if [[ $BACKUP_STORE_TYPE = "s3" ]]; then
    BACKUP_STORE_FOR_TEST=`yq e 'select(.spec.containers[0] != null).spec.containers[0].env[1].value' ${LONGHORN_TESTS_MANIFEST_FILE_PATH} | awk -F ',' '{print $1}' | sed 's/ *//'`
    yq e -i 'select(.spec.containers[0] != null).spec.containers[0].env[1].value="'${BACKUP_STORE_FOR_TEST}'"' ${LONGHORN_TESTS_MANIFEST_FILE_PATH}
  elif [[ $BACKUP_STORE_TYPE = "nfs" ]]; then
    BACKUP_STORE_FOR_TEST=`yq e 'select(.spec.containers[0] != null).spec.containers[0].env[1].value' ${LONGHORN_TESTS_MANIFEST_FILE_PATH} | awk -F ',' '{print $2}' | sed 's/ *//'`
    yq e -i 'select(.spec.containers[0] != null).spec.containers[0].env[1].value="'${BACKUP_STORE_FOR_TEST}'"' ${LONGHORN_TESTS_MANIFEST_FILE_PATH}
  fi

  if [[ "${TF_VAR_use_hdd}" == true ]]; then
    yq e -i 'select(.spec.containers[0] != null).spec.containers[0].env[3].value="hdd"' ${LONGHORN_TESTS_MANIFEST_FILE_PATH}
  fi

  if [[ "${TF_VAR_k8s_distro_name}" == "eks" ]] || [[ "${TF_VAR_k8s_distro_name}" == "aks" ]]; then
    yq e -i 'select(.spec.containers[0] != null).spec.containers[0].env[6].value="true"' ${LONGHORN_TESTS_MANIFEST_FILE_PATH}
  fi

  set +x
  ## inject aws cloudprovider and credentials env variables from created secret
  yq e -i 'select(.spec.containers[0].env != null).spec.containers[0].env += {"name": "CLOUDPROVIDER", "value": "aws"}' "${LONGHORN_TESTS_MANIFEST_FILE_PATH}"
  yq e -i 'select(.spec.containers[0].env != null).spec.containers[0].env += {"name": "AWS_ACCESS_KEY_ID", "valueFrom": {"secretKeyRef": {"name": "aws-cred-secret", "key": "AWS_ACCESS_KEY_ID"}}}' "${LONGHORN_TESTS_MANIFEST_FILE_PATH}"
  yq e -i 'select(.spec.containers[0].env != null).spec.containers[0].env += {"name": "AWS_SECRET_ACCESS_KEY", "valueFrom": {"secretKeyRef": {"name": "aws-cred-secret", "key": "AWS_SECRET_ACCESS_KEY"}}}' "${LONGHORN_TESTS_MANIFEST_FILE_PATH}"
  yq e -i 'select(.spec.containers[0].env != null).spec.containers[0].env += {"name": "AWS_DEFAULT_REGION", "valueFrom": {"secretKeyRef": {"name": "aws-cred-secret", "key": "AWS_DEFAULT_REGION"}}}' "${LONGHORN_TESTS_MANIFEST_FILE_PATH}"
  set -x

  LONGHORN_TEST_POD_NAME=`yq e 'select(.spec.containers[0] != null).metadata.name' ${LONGHORN_TESTS_MANIFEST_FILE_PATH}`

  kubectl apply -f ${LONGHORN_TESTS_MANIFEST_FILE_PATH}

  local RETRY_COUNTS=60
  local RETRIES=0
  # wait longhorn tests pod to start running
  while [[ -n "`kubectl get pod longhorn-test -o=jsonpath='{.status.containerStatuses[?(@.name=="longhorn-test")].state}' | grep -v \"running\|terminated\"`"  ]]; do
    echo "waiting longhorn test pod to be in running state ... rechecking in 10s"
    sleep 10s
    RETRIES=$((RETRIES+1))

    if [[ ${RETRIES} -eq ${RETRY_COUNTS} ]]; then echo "Error: longhorn test pod start timeout"; exit 1 ; fi
  done

  # wait longhorn tests to complete
  while [[ "`kubectl get pod longhorn-test -o=jsonpath='{.status.containerStatuses[?(@.name=="longhorn-test")].state}' 2>&1 | grep -v \"terminated\"`"  ]]; do
    kubectl logs ${LONGHORN_TEST_POD_NAME} -c longhorn-test -f --since=10s
  done

  kubectl cp ${LONGHORN_TEST_POD_NAME}:/tmp/test-report/log.html "log.html" -c longhorn-test-report
  kubectl cp ${LONGHORN_TEST_POD_NAME}:/tmp/test-report/output.xml "output.xml" -c longhorn-test-report
  kubectl cp ${LONGHORN_TEST_POD_NAME}:/tmp/test-report/report.html "report.html" -c longhorn-test-report
}

run_longhorn_e2e_test_out_of_cluster(){

  if [[ ${BACKUP_STORE_TYPE} == "s3" ]]; then
    LONGHORN_BACKUPSTORES='s3://backupbucket@us-east-1/backupstore$minio-secret'
  elif [[ $BACKUP_STORE_TYPE = "nfs" ]]; then
    LONGHORN_BACKUPSTORES='nfs://longhorn-test-nfs-svc.default:/opt/backupstore'
  fi
  LONGHORN_BACKUPSTORE_POLL_INTERVAL="30"

  eval "ROBOT_COMMAND_ARGS=($PYTEST_CUSTOM_OPTIONS)"

  if [[ -n ${LONGHORN_TESTS_CUSTOM_IMAGE} ]]; then
    cat /tmp/instance_mapping
    cp "${KUBECONFIG}" /tmp/kubeconfig
    CONTAINER_NAME="e2e-container-${IMAGE_NAME}"
    docker run --pull=always \
               --name "${CONTAINER_NAME}" \
               -e LONGHORN_BACKUPSTORE="${LONGHORN_BACKUPSTORES}" \
               -e LONGHORN_BACKUPSTORE_POLL_INTERVAL="${LONGHORN_BACKUPSTORE_POLL_INTERVAL}" \
               -e AWS_ACCESS_KEY_ID="${TF_VAR_lh_aws_access_key}" \
               -e AWS_SECRET_ACCESS_KEY="${TF_VAR_lh_aws_secret_key}" \
               -e AWS_DEFAULT_REGION="${TF_VAR_aws_region}" \
               -e LONGHORN_CLIENT_URL="${LONGHORN_CLIENT_URL}" \
               -e KUBECONFIG="/tmp/kubeconfig" \
               --mount source="vol-${IMAGE_NAME}",target=/tmp \
               "${LONGHORN_TESTS_CUSTOM_IMAGE}" "${ROBOT_COMMAND_ARGS[@]}"
    docker stop "${CONTAINER_NAME}"
    docker rm "${CONTAINER_NAME}"
  else
    export LONGHORN_BACKUPSTORES=${LONGHORN_BACKUPSTORES}
    export LONGHORN_BACKUPSTORE_POLL_INTERVAL=${LONGHORN_BACKUPSTORE_POLL_INTERVAL}
    cd e2e
    python3 -m venv .
    source bin/activate
    pip install -r requirements.txt
    ./run.sh "${ROBOT_COMMAND_ARGS[@]}"
  fi

  cp /tmp/test-report/log.html "${WORKSPACE}/log.html"
  cp /tmp/test-report/output.xml "${WORKSPACE}/output.xml"
  cp /tmp/test-report/report.html "${WORKSPACE}/report.html"
}
