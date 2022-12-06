#!/bin/bash

set -ex

sed -i 's#^SELINUX=.*$#SELINUX='"${selinux_mode}"'#' /etc/selinux/config

if [[ ${selinux_mode} == "enforcing" ]] ; then
    setenforce  1
elif [[  ${selinux_mode} == "permissive" ]]; then
    setenforce  0
fi

yum update -y
yum group install -y "Development Tools"
yum install -y iscsi-initiator-utils nfs-utils nfs4-acl-tools jq
systemctl -q enable iscsid
systemctl start iscsid
systemctl disable nm-cloud-setup.service nm-cloud-setup.timer

until (curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-taint "node-role.kubernetes.io/master=true:NoExecute" --node-taint "node-role.kubernetes.io/master=true:NoSchedule" --tls-san ${k3s_server_public_ip} --write-kubeconfig-mode 644 --token ${k3s_cluster_secret}" INSTALL_K3S_VERSION="${k3s_version}" sh -); do
  echo 'k3s server did not install correctly'
  sleep 2
done

until (kubectl get pods -A | grep 'Running'); do
  echo 'Waiting for k3s startup'
  sleep 5
done
