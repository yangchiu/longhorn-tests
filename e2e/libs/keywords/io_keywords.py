from io_chaos import IOChaos


class io_keywords:

    def __init__(self):
        self.io = IOChaos()

    def inject_latency(self):
        self.io.inject_latency()

    def cancel_injection(self):
        self.io.cancel_injection()
