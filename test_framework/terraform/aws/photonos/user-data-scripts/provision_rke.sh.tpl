#!/bin/bash

DOCKER_VERSION=20.10

yum update -y
yum install -y open-iscsi nfs-utils jq rsync
systemctl -q enable iscsid
systemctl start iscsid
systemctl stop iptables
systemctl disable iptables

if [ -b "/dev/xvdh" ]; then
  mkfs.ext4 -E nodiscard /dev/xvdh
  mkdir /var/lib/longhorn
  mount /dev/xvdh /var/lib/longhorn
fi

until (curl https://releases.rancher.com/install-docker/$${DOCKER_VERSION}.sh | sh); do
  echo 'docker did not install correctly'
  sleep 2
done

usermod -aG docker ec2-user
