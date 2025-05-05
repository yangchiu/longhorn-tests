#!/usr/bin/env bash

# terminate any terraform processes
TERRAFORM_PIDS=( `ps aux | grep -i terraform | grep -v grep | awk '{printf("%s ",$1)}'` )
if [[ -n ${TERRAFORM_PIDS[@]} ]] ; then
	for PID in "${TERRAFORM_PIDS[@]}"; do
		kill "${TERRAFORM_PIDS}"
	done
fi

# wait 30 seconds for graceful terraform termination
sleep 30

terraform -chdir=test_framework/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO} destroy -auto-approve -no-color

if [[ ${LONGHORN_TEST_CLOUDPROVIDER} == "harvester" ]]; then
  # delete harvester cloud credential after harvester cluster has been deleted successfully
  sed -i '/lifecycle {/,/}/d' "test_framework/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO}/main.tf"
  terraform -chdir=test_framework/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO} apply -auto-approve -no-color
  terraform -chdir=test_framework/terraform/${LONGHORN_TEST_CLOUDPROVIDER}/${DISTRO} destroy -auto-approve -no-color
fi
