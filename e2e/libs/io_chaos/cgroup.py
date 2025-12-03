from utility.utility import logging
from node import Node
from node_exec import NodeExec
import time


class Cgroup:

    def __init__(self):
        pass

    def inject_latency(self):
        worker_nodes = Node().list_node_names_by_role("worker")
        # lsblk -ndo NAME,MAJ:MIN
        # xvda  202:0
        # xvdh  202:112
        # inject latency on /var/lib/longhorn for v1 volumes
        for worker_node in worker_nodes:
            NodeExec(worker_node).issue_cmd(
                'set -x; mkdir -p /sys/fs/cgroup/slowlh && echo "202:0 rbps=1048576 wbps=1048576 riops=10 wiops=10" > /sys/fs/cgroup/slowlh/io.max'
            )
            NodeExec(worker_node).issue_cmd(
                'for pid in $(pgrep -f longhorn); do echo $pid > /sys/fs/cgroup/slowlh/cgroup.procs; done'
            )

    def cancel_injection(self):
        worker_nodes = Node().list_node_names_by_role("worker")
        # restore /var/lib/longhorn for v1 volumes
        for worker_node in worker_nodes:
            NodeExec(worker_node).issue_cmd(
                'for pid in $(pgrep -f longhorn); do echo $pid > /sys/fs/cgroup/cgroup.procs 2>/dev/null; done && rmdir /sys/fs/cgroup/slowlh'
            )
