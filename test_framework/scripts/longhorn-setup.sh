#!/usr/bin/env bash


set_kubeconfig_envvar(){
  export KUBECONFIG=${PWD}/rke_cluster.yaml
  kubectl config set-context local
  kubectl config use-context local
  kubectl get node -o wide
}


install_backupstores(){
  MINIO_BACKUPSTORE_URL="https://raw.githubusercontent.com/longhorn/longhorn-tests/master/manager/integration/deploy/backupstores/minio-backupstore.yaml"
  NFS_BACKUPSTORE_URL="https://raw.githubusercontent.com/longhorn/longhorn-tests/master/manager/integration/deploy/backupstores/nfs-backupstore.yaml"
  kubectl create -f ${MINIO_BACKUPSTORE_URL} \
	             -f ${NFS_BACKUPSTORE_URL}
}


run_longhorn_tests(){

	LONGHORN_TESTS_MANIFEST_FILE_PATH="${PWD}/manager/integration/deploy/test.yaml"

	LONGHORN_JUNIT_REPORT_PATH=`yq e '.spec.containers[0].env[] | select(.name == "LONGHORN_JUNIT_REPORT_PATH").value' "${LONGHORN_TESTS_MANIFEST_FILE_PATH}"`

	LONGHORN_TEST_POD_NAME=`yq e 'select(.metadata.labels != null and .spec.containers[0] != null).metadata.name' ${LONGHORN_TESTS_MANIFEST_FILE_PATH}`

  echo "${LONGHORN_TESTS_MANIFEST_FILE_PATH}"

  local PYTEST_COMMAND_ARGS='"-s", "--junitxml='${LONGHORN_JUNIT_REPORT_PATH}'", "-k", "test_allow_volume_creation_with_degraded_availability_restore "'
	if [[ -n ${PYTEST_CUSTOM_OPTIONS} ]]; then
        PYTEST_CUSTOM_OPTIONS=(${PYTEST_CUSTOM_OPTIONS})

        for OPT in "${PYTEST_CUSTOM_OPTIONS[@]}"; do
            PYTEST_COMMAND_ARGS=${PYTEST_COMMAND_ARGS}', "'${OPT}'"'
        done
  fi

	## generate test pod manifest
  yq e -i 'select(.metadata.labels != null and .spec.containers[0] != null).spec.containers[0].args=['"${PYTEST_COMMAND_ARGS}"']' "${LONGHORN_TESTS_MANIFEST_FILE_PATH}"

	kubectl apply -f ${LONGHORN_TESTS_MANIFEST_FILE_PATH}

	local RETRY_COUNTS=60
	local RETRIES=0
	# wait longhorn tests pod to start running
    while [[ -n "`kubectl get pods "${LONGHORN_TEST_POD_NAME}" --no-headers=true | awk '{print $3}' | grep -v \"Running\|Completed\"`"  ]]; do
        echo "waiting longhorn test pod to be in running state ... rechecking in 10s"
        sleep 10s
		RETRIES=$((RETRIES+1))

		if [[ ${RETRIES} -eq ${RETRY_COUNTS} ]]; then echo "Error: longhorn test pod start timeout"; exit 1 ; fi
    done

  kubectl logs ${LONGHORN_TEST_POD_NAME} -f
    # wait longhorn tests to complete
    #local LOG_LINE_COUNT=0
    #while [[ -z "`kubectl get pods ${LONGHORN_TEST_POD_NAME} --no-headers=true | awk '{print $3}' | grep -v Running`"  ]]; do
    #    #echo -e "\nLonghorn tests still running ... rechecking in 1m"
    #    local NEW_LINE_COUNT=`kubectl exec -i ${LONGHORN_TEST_POD_NAME} -- bash -c 'wc -l < /tmp/longhorn-pytest'`
    #    if [[ LOG_LINE_COUNT -ne NEW_LINE_COUNT ]]; then
    #        kubectl exec -i ${LONGHORN_TEST_POD_NAME} -- tail -n +$((LOG_LINE_COUNT+1)) /tmp/longhorn-pytest
    #        LOG_LINE_COUNT=${NEW_LINE_COUNT}
    #    fi
    #    #echo "LOG_LINE_COUNT=${LOG_LINE_COUNT}"
    #    #echo "NEW_LINE_COUNT=${NEW_LINE_COUNT}"
    #    #echo "LOG_LINE_COUNT+1=$((LOG_LINE_COUNT+1))"
    #    sleep 1m
    #done

	kubectl cp test-report:${LONGHORN_JUNIT_REPORT_PATH} ./longhorn-test-junit-report.xml
}


main(){
	set_kubeconfig_envvar
	install_backupstores
	run_longhorn_tests
}

main
