from strategy import LonghornOperationStrategy

from sharemanager.base import Base
from sharemanager.crd import CRD
from sharemanager.rest import Rest


class ShareManager(Base):

    _strategy = LonghornOperationStrategy.CRD

    def __init__(self):
        if self._strategy == LonghornOperationStrategy.CRD:
            self.sharemanager = CRD()
        else:
            self.sharemanager = Rest()

    def list(self):
        return self.sharemanager.list()
