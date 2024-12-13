from persistentvolume import PersistentVolume

from utility.utility import logging


class persistentvolume_keywords:

    def __init__(self):
        self.pv = PersistentVolume()

    def delete_persistentvolume(self, name):
        logging(f'Deleting persistentvolume {name}')
        return self.pv.delete(name)

    def wait_for_persistentvolume_created(self, name):
        logging(f'Waiting for persistentvolume {name} created')
        return self.pv.wait_for_created(name)
