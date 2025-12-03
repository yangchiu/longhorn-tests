from io_chaos.cgroup import Cgroup
from io_chaos.device_mapper import DeviceMapper
from io_chaos.chaos_mesh import ChaosMesh


class IOChaos:

    def __init__(self):
        self.io = ChaosMesh() #DeviceMapper() #Cgroup()

    def inject_latency(self):
        self.io.inject_latency()

    def cancel_injection(self):
        self.io.cancel_injection()
