from network.network import inject_control_plane_network_latency
from network.network import recover_control_plane_network

class network_keywords:

    def inject_control_plane_network_latency(self):
        inject_control_plane_network_latency()

    def recover_control_plane_network(self):
        recover_control_plane_network()
