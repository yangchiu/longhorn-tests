#!/bin/bash

set -ex

dnf update -y
dnf group install -y "Development Tools"
dnf install -y iscsi-initiator-utils nfs-utils nfs4-acl-tools
systemctl -q enable iscsid
systemctl start iscsid
systemctl disable nm-cloud-setup.service nm-cloud-setup.timer

if [ -b "/dev/xvdh" ]; then
  mkfs.ext4 -E nodiscard /dev/xvdh
  mkdir /var/lib/longhorn
  mount /dev/xvdh /var/lib/longhorn
fi

sed -i 's#^SELINUX=.*$#SELINUX='"${selinux_mode}"'#' /etc/selinux/config

if [[ ${selinux_mode} == "enforcing" ]] ; then
    setenforce  1
elif [[  ${selinux_mode} == "permissive" ]]; then
    setenforce  0
fi

until (curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --token ${k3s_cluster_secret}" K3S_URL="${k3s_server_url}" INSTALL_K3S_VERSION="${k3s_version}" sh -); do
  echo 'k3s agent did not install correctly'
  sleep 2
done
