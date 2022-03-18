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
	LONGHORH_TESTS_REPO_BASEDIR=${1}

	LONGHORN_TESTS_CUSTOM_IMAGE=${LONGHORN_TESTS_CUSTOM_IMAGE:-"longhornio/longhorn-manager-test:master-head"}

	LONGHORN_TESTS_MANIFEST_FILE_PATH="${LONGHORH_TESTS_REPO_BASEDIR}/manager/integration/deploy/test.yaml"

	LONGHORN_JUNIT_REPORT_PATH=`yq e '.spec.containers[0].env[] | select(.name == "LONGHORN_JUNIT_REPORT_PATH").value' "${LONGHORN_TESTS_MANIFEST_FILE_PATH}"`

	local PYTEST_COMMAND_ARGS='"-s", "--junitxml='${LONGHORN_JUNIT_REPORT_PATH}'"'
	if [[ -n ${PYTEST_CUSTOM_OPTIONS} ]]; then
        PYTEST_CUSTOM_OPTIONS=(${PYTEST_CUSTOM_OPTIONS})

        for OPT in "${PYTEST_CUSTOM_OPTIONS[@]}"; do
            PYTEST_COMMAND_ARGS=${PYTEST_COMMAND_ARGS}', "'${OPT}'"'
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

	LONGHORN_TEST_POD_NAME=`yq e 'select(.spec.containers[0] != null).metadata.name' ${LONGHORN_TESTS_MANIFEST_FILE_PATH}`

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

    # wait longhorn tests to complete
    while [[ -z "`kubectl get pods ${LONGHORN_TEST_POD_NAME} --no-headers=true | awk '{print $3}' | grep -v Running`"  ]]; do
        echo "Longhorn tests still running ... rechecking in 5m"
        sleep 5m
    done

	kubectl logs ${LONGHORN_TEST_POD_NAME}  >> "${TF_VAR_tf_workspace}/longhorn-test-junit-report.xml"
}


main(){
	set_kubeconfig_envvar
	install_backupstores
	run_longhorn_tests ${WORKSPACE}
}

main
