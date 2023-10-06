from utility.utility import logging
from node_exec import NodeExec
import time

def restart_kubelet(node_name, stop_time_in_sec=10):
    filepath = "./templates/kubelet/kubelet_restart.sh"
    dst_filepath = "/tmp/kubelet_restart.sh"
    with open(filepath, 'r') as f:
        content = f.read()
        cmd = [
            "sh",
            "-c",
            f"touch {dst_filepath}; chmod +x {dst_filepath}; cat > {dst_filepath} <<-'EOF'\n{content}\nEOF"
        ]
        res = NodeExec.get_instance().issue_cmd(node_name, cmd)
        cmd = [
            "sh",
            "-c",
            f"{dst_filepath} {stop_time_in_sec} > /dev/null 2> /dev/null &"
        ]
        res = NodeExec.get_instance().issue_cmd(node_name, cmd)
        time.sleep(stop_time_in_sec)