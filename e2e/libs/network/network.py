from robot.libraries.BuiltIn import BuiltIn
from utility.utility import get_control_plane_node
from utility.utility import logging
from node_exec import NodeExec
import time

def get_latency_in_ms():
    latency_ms_ms = int(BuiltIn().get_variable_value("${LATENCY_IN_MS}"))
    return latency_ms_ms

def inject_control_plane_network_latency():
    latency_in_ms = get_latency_in_ms()
    if latency_in_ms != 0:
        cmd = f"tc qdisc replace dev eth0 root netem delay {latency_in_ms}ms"
        res = NodeExec.get_instance().issue_cmd(get_control_plane_node(), cmd)
        cmd = f"tc qdisc show dev eth0 | grep delay"
        res = NodeExec.get_instance().issue_cmd(get_control_plane_node(), cmd)
        assert res, "inject control plane network latency failed"

def recover_control_plane_network():
    latency_in_ms = get_latency_in_ms()
    if latency_in_ms != 0:
        cmd = "tc qdisc del dev eth0 root"
        res = NodeExec.get_instance().issue_cmd(get_control_plane_node(), cmd)
        cmd = f"tc qdisc show dev eth0 | grep -v delay"
        res = NodeExec.get_instance().issue_cmd(get_control_plane_node(), cmd)
        assert res, "recover control plane network failed"

def disconnect_node_network(node_name, disconnection_time_in_sec=10):
    filepath = "./templates/network/network_down.sh"
    dst_filepath = "/tmp/network_down.sh"
    with open(filepath, 'r') as f:
        content = f.read()
        cmd = f"touch {dst_filepath}; chmod +x {dst_filepath}; cat > {dst_filepath} <<-'EOF'\n{content}\nEOF"
        res = NodeExec.get_instance().issue_cmd(node_name, cmd)
        cmd = f"{dst_filepath} {disconnection_time_in_sec} > /dev/null 2> /dev/null &"
        res = NodeExec.get_instance().issue_cmd(node_name, cmd)
        time.sleep(disconnection_time_in_sec)
