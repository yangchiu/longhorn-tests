from utility.utility import logging
from node import Node
from node_exec import NodeExec
import time


class DeviceMapper:

    def __init__(self):
        self.node = Node()

    def inject_latency(self):
        worker_nodes = self.node.list_node_names_by_role("worker")
        for worker_node in worker_nodes:
            self.node.reset_disks(worker_node)
            # use delayed device created by
            # SECTORS=$(blockdev --getsz /dev/xvdh)
            # echo "0 $SECTORS delay /dev/xvdh 0 200" | dmsetup create lhdelay
            disk = {
                "block-disk": {
                    "diskType": "block",
                    "path": "/dev/mapper/lhdelay",
                    "allowScheduling": True
                }
            }
            self.node.add_disk(worker_node, disk)

    def cancel_injection(self):
        worker_nodes = self.node.list_node_names_by_role("worker")
        for worker_node in worker_nodes:
            self.node.reset_disks(worker_node)
            disk = {
                "block-disk": {
                    "diskType": "block",
                    "path": "/dev/xvdh",
                    "allowScheduling": True
                }
            }
            self.node.add_disk(worker_node, disk)
