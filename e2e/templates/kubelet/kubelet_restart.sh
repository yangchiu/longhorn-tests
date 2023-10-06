#!/bin/bash

STOP_TIME_IN_SEC=$1

sleep 3; # avoid remote host connection lost before pod execution returns
systemctl stop k3s-agent;
sleep "${STOP_TIME_IN_SEC}";
systemctl start k3s-agent;