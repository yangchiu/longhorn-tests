#!/bin/bash

set -x

docker build --no-cache -f ./test_framework/Dockerfile.setup --build-arg KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)" -t "${JOB_BASE_NAME}-${BUILD_NUMBER}" .
