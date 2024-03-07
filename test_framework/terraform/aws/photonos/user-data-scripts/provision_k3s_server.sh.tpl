#!/bin/bash

set -e

yum update -y
yum install -y open-iscsi nfs-utils jq rsync
systemctl -q enable iscsid
systemctl start iscsid
systemctl stop iptables
systemctl disable iptables

until (curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-taint "node-role.kubernetes.io/master=true:NoExecute" --node-taint "node-role.kubernetes.io/master=true:NoSchedule" --tls-san ${k3s_server_public_ip} --write-kubeconfig-mode 644 --token ${k3s_cluster_secret}" INSTALL_K3S_VERSION="${k3s_version}" sh -); do
  echo 'k3s server did not install correctly'
  sleep 2
done

until (/usr/local/bin/kubectl get pods -A | grep 'Running'); do
  echo 'Waiting for k3s startup'
  sleep 5
done

if [[ -n "${custom_ssh_public_key}" ]]; then
  echo "${custom_ssh_public_key}" >> /home/ec2-user/.ssh/authorized_keys
fi