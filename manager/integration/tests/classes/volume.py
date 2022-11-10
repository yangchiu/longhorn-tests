from ..common import generate_volume_name, SIZE, VOLUME_FRONTEND_BLOCKDEV
from ..common import create_and_check_volume, wait_for_volume_healthy, write_volume_random_data


class Volume:

    def __init__(self,
                 client,
                 volume_name=generate_volume_name(),
                 num_of_replicas=3,
                 size=SIZE,
                 backing_image="",
                 frontend=VOLUME_FRONTEND_BLOCKDEV):
        self.client = client
        self.volume_name = volume_name
        self.num_of_replicas = num_of_replicas
        self.size = size
        self.backing_image = backing_image
        self.frontend = frontend

        create_and_check_volume(self.client,
                                self.volume_name,
                                num_of_replicas=self.num_of_replicas,
                                size=self.size,
                                backing_image=self.backing_image,
                                frontend=self.frontend)

    def attach(self, host_id):
        volume = self.client.by_id_volume(self.volume_name)
        volume.attach(hostId=host_id)
        wait_for_volume_healthy(self.client, self.volume_name)

    def write_random_data(self):
        volume = self.client.by_id_volume(self.volume_name)
        self.volume_data = write_volume_random_data(volume)
