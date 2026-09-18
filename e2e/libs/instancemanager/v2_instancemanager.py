import uuid
import time

from instancemanager.base import Base

from utility.utility import logging
from utility.utility import subprocess_exec_cmd
import utility.constant as constant
from utility.constant import DEFAULT_BLOCK_DISK_NAME

class V2_InstanceManager(Base):

    def __init__(self):
        super().__init__()

    def get_replicas(self, node_name):
        im_pod_name = self.get_instance_manager_pod_on_node(node_name, "v2")
        cmd = f"kubectl exec -n {constant.LONGHORN_NAMESPACE} {im_pod_name} -- go-spdk-helper lvol get"
        output = subprocess_exec_cmd(cmd)
        return output

    def create_orphaned_replica(self, node_name, volume_name):
        orphaned_replica = f"{volume_name}-r-{uuid.uuid4().hex[:8]}"

        logging(f"Creating orphaned replica {orphaned_replica} on node {node_name} in lvs {DEFAULT_BLOCK_DISK_NAME}")

        im_pod_name = self.get_instance_manager_pod_on_node(node_name, "v2")
        cmd = (f"kubectl exec -n {constant.LONGHORN_NAMESPACE} {im_pod_name} -- "
               f"go-spdk-helper lvol create "
               f"--lvs-name {DEFAULT_BLOCK_DISK_NAME} "
               f"--lvol-name {orphaned_replica} "
               f"--size 1024")
        subprocess_exec_cmd(cmd)

        logging(f"Created orphaned replica {orphaned_replica} on node {node_name}")
        return orphaned_replica

    def crash_replica(self, node_name, replica_name):
        # v2 replicas are backed by SPDK lvols instead of a plain directory on
        # the host filesystem, so there is no `chattr +i`-like way to make a
        # lvol immutable. `go-spdk-helper lvol delete` doesn't fail the
        # replica permanently either: it doesn't actually stop Longhorn from
        # rebuilding/reusing the replica afterwards. Instead, to achieve an
        # equivalent permanent replica crash, talk to the SPDK JSON-RPC
        # socket directly (via a small python3 script run inside the
        # instance-manager container) and call `bdev_lvol_set_read_only` on
        # the lvol. This makes the lvol read-only at the SPDK level, so any
        # further writes Longhorn attempts against it (e.g. while trying to
        # reuse/rebuild the replica) will fail, leaving the replica
        # permanently unusable.
        #
        # The instance-manager pod name is re-resolved on every attempt (and
        # the whole operation retried) because the pod can be transiently
        # unreachable/recreated (e.g. right after a node disruption), which
        # would otherwise cause a one-shot `kubectl exec` to fail with a
        # stale pod name.
        alias = f"{DEFAULT_BLOCK_DISK_NAME}/{replica_name}"
        logging(f"Crashing replica {replica_name} on node {node_name} by setting lvol {alias} read-only")

        script = (
            "import socket, json, sys\n"
            "s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n"
            "s.connect('/var/tmp/spdk.sock')\n"
            "req = {'jsonrpc': '2.0', 'id': 1, 'method': 'bdev_lvol_set_read_only', "
            f"'params': {{'name': '{alias}'}}}}\n"
            "s.sendall(json.dumps(req).encode())\n"
            "buf = b''\n"
            "while True:\n"
            "    buf += s.recv(65536)\n"
            "    try:\n"
            "        resp = json.loads(buf.decode())\n"
            "        print(json.dumps(resp, indent=2))\n"
            "        break\n"
            "    except ValueError:\n"
            "        pass\n"
            "if 'error' in resp:\n"
            "    raise SystemExit(1)\n"
        )

        last_error = None
        for i in range(self.retry_count):
            try:
                im_pod_name = self.get_instance_manager_pod_on_node(node_name, "v2")
                cmd = (f"kubectl exec -n {constant.LONGHORN_NAMESPACE} {im_pod_name} -- "
                       f"python3 -c \"{script}\"")
                output = subprocess_exec_cmd(cmd)
                logging(f"Crashed replica {replica_name} on node {node_name} by setting lvol {alias} read-only: {output}")
                return
            except Exception as e:
                last_error = e
                logging(f"Failed to crash replica {replica_name} on node {node_name} ... ({i}): {e}")
            time.sleep(self.retry_interval)
        assert False, f"Failed to crash replica {replica_name} on node {node_name} by setting lvol {alias} read-only: {last_error}"

    def wait_for_replica_deleted(self, node_name, replica_name):
        # v2 replica directory name is also not the same as v2 replica name
        # but since `go-spdk-helper lvol get` returns all detailed info including the replica name and replica directory name
        # it's safe to directly use the replica name for verification
        for i in range(self.retry_count):
            logging(f"Waiting for replica {replica_name} to be deleted from spdk on node {node_name} ... ({i})")
            try:
                replicas_output = self.get_replicas(node_name)
                if replica_name not in replicas_output:
                    return
            except Exception as e:
                logging(f"Failed to wait for replica {replica_name} to be deleted from spdk on node {node_name}: {e}")
            time.sleep(self.retry_interval)
        assert False, f"Failed to wait for replica {replica_name} to be deleted from spdk on node {node_name}"

    def wait_for_replica_present(self, node_name, replica_name):
        # v2 replica directory name is also not the same as v2 replica name
        # but since `go-spdk-helper lvol get` returns all detailed info including the replica name and replica directory name
        # it's safe to directly use the replica name for verification
        for i in range(self.retry_count):
            logging(f"Waiting for replica {replica_name} to be present in spdk on node {node_name} ... ({i})")
            try:
                replicas_output = self.get_replicas(node_name)
                if replica_name in replicas_output:
                    return
            except Exception as e:
                logging(f"Failed to wait for replica {replica_name} to be present in spdk on node {node_name}: {e}")
            time.sleep(self.retry_interval)
        assert False, f"Failed to wait for replica {replica_name} to be present in spdk on node {node_name}"
