from utility.utility import logging
from utility.utility import subprocess_exec_cmd


class ChaosMesh:

    def __init__(self):
        pass

    def inject_latency(self):
        filepath = f"./templates/chaosmesh/io_latency.yaml"
        subprocess_exec_cmd(f"kubectl apply -f {filepath}")

    def cancel_injection(self):
        subprocess_exec_cmd(f"kubectl patch iochaos lh-latency -n chaos-mesh -p '{{\"metadata\":{{\"finalizers\":null}}}}' --type=merge; kubectl delete iochaos lh-latency -n chaos-mesh;")
