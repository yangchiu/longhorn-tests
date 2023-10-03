#!/bin/bash

DISCONNECTION_TIME_IN_SEC=$1

sleep 3; # avoid loss network connection before pod execution returns
tc qdisc replace dev eth0 root netem loss 100%;
sleep "${DISCONNECTION_TIME_IN_SEC}";
tc qdisc del dev eth0 root;
