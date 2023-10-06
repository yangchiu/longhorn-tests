from robot.libraries.BuiltIn import BuiltIn
from utility.utility import get_control_plane_node
from utility.utility import logging
from node_exec import NodeExec
import time

def get_latency_in_ms():
    latency_in_ms = BuiltIn().get_variable_value("${LATENCY_IN_MS}")
    if latency_in_ms:
        latency_in_ms = int(latency_in_ms)
    else:
        latency_in_ms = 0
    return latency_in_ms

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
    #cmd = f"sleep 5 && tc qdisc replace dev eth0 root netem loss 100% && sleep {disconnection_time_in_sec} && tc qdisc del dev eth0 root"
    #cmd = f"sleep 10 && systemctl stop k3s-agent.service && sleep {disconnection_time_in_sec} && systemctl start k3s-agent.service"
    #cmd = f"systemctl show --no-pager k3s-agent | grep SubState"
    cmd = [
        "sh",
        "-c",
        "systemctl is-active k3s-agent"
    ]
    #cmd = f"systemctl stop k3s-agent"
    res = NodeExec.get_instance().issue_cmd(node_name, cmd)
    '''
    filepath = "./templates/network/network_down.sh"
    dst_filepath = "/tmp/network_down.sh"
    with open(filepath, 'r') as f:
        content = f.read()
        cmd = f"touch {dst_filepath}; chmod +x {dst_filepath}; cat > {dst_filepath} <<-'EOF'\n{content}\nEOF"
        res = NodeExec.get_instance().issue_cmd(node_name, cmd)
        cmd = f"{dst_filepath} {disconnection_time_in_sec} > /dev/null 2> /dev/null &"
        res = NodeExec.get_instance().issue_cmd(node_name, cmd)
        time.sleep(disconnection_time_in_sec)
    '''
