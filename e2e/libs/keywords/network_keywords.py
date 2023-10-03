from network.network import inject_control_plane_network_latency
from network.network import recover_control_plane_network
from network.network import disconnect_node_network
from utility.utility import get_node

class network_keywords:

    def inject_control_plane_network_latency(self):
        inject_control_plane_network_latency()

    def recover_control_plane_network(self):
        recover_control_plane_network()

    def disconnect_node_network(self, node_name, disconnection_time_in_sec):
        disconnect_node_network(node_name, int(disconnection_time_in_sec))
