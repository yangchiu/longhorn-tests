import socket

from behave import fixture
from behave import use_fixture
from kubernetes import client as k8sclient
from kubernetes import config as k8sconfig
from kubernetes.client import Configuration

import sys
sys.path.append('../')
import common


@fixture
def core_api(context):
    """
    Create a new CoreV1API instance.
    Returns:
        A new CoreV1API Instance.
    """
    c = Configuration()
    c.assert_hostname = False
    Configuration.set_default(c)
    k8sconfig.load_incluster_config()
    core_api = k8sclient.CoreV1Api()

    context.core_api = core_api
    yield context.core_api


@fixture
def client(context):
    """
    Return an individual Longhorn API client for testing.
    """
    k8sconfig.load_incluster_config()
    # Make sure nodes and managers are all online.
    ips = common.get_mgr_ips()

    # check if longhorn manager port is open before calling get_client
    client = None
    for ip in ips:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        mgr_port_open = sock.connect_ex((ip, 9500))

        if mgr_port_open == 0:
            client = common.get_client(ip + common.PORT)
            break

    if client is not None:
        hosts = client.list_node()
        assert len(hosts) == len(ips)
    else:
        raise RuntimeError('Expect client exists, but it\'s None')

    context.client = client
    yield context.client

    common.cleanup_client()


class Volume:

    def __init__(self, name, volume):
        self.name = name
        self.volume = volume
        self.snapshots = {}
        self.backups = {}

    def add_snapshot(self, name, snapshot):
        self.snapshots[name] = snapshot

    def add_backup(self, name, backup):
        self.backups[name] = backup


class Backup:

    def __init__(self, name, backup, snapshot, volume):
        self.name = name
        self.backup = backup
        self.snapshot = snapshot
        self.volume = volume


@fixture
def volumes(context):

    context.volumes = {}
    context.current_volume = None
    context.current_volume_name = None

    def add_volume(volume_name, volume):
        context.volumes[volume_name] = volume
        context.current_volume_name = volume_name
        context.current_volume = volume
    context.add_volume = add_volume

    def get_volume_by_name(name):
        return context.volumes[name]
    context.get_volume_by_name = get_volume_by_name

    context.volume_name = None
    context.volume = None


@fixture
def snapshots(context):

    context.snapshots = {}

    def add_snapshot(snapshot_name, snapshot):
        context.snapshots[snapshot_name] = snapshot
    context.add_snapshot = add_snapshot

    def get_snapshot_by_name(name):
        return context.snapshots[name]
    context.get_snapshot_by_name = get_snapshot_by_name


@fixture
def backups(context):

    context.backups = {}

    def add_backup(backup_name, backup, snapshot, volume):
        context.backups[backup_name] = Backup(backup_name, backup, snapshot, volume)
    context.add_backup = add_backup

    def get_backup_by_name(name):
        return context.backups[name]
    context.get_backup_by_name = get_backup_by_name


@fixture
def replicas(context):

    context.replicas = {}

    def add_replica(replica_name, replica):
        context.replicas[replica_name] = replica
    context.add_replica = add_replica

    def get_replica_by_name(name):
        return context.replicas[name]
    context.get_replica_by_name = get_replica_by_name


@fixture
def nodes(context):

    context.nodes = {}

    def add_node(node_name, node):
        context.nodes[node_name] = node
    context.add_node = add_node

    def get_node_by_name(name):
        return context.nodes[name]
    context.get_node_by_name = get_node_by_name


@fixture
def data(context):

    context.data = {}

    def add_data(data_name, data):
        context.data[data_name] = data
    context.add_data = add_data


@fixture
def current(context):

    context.volume_name = None
    context.volume = None

    def set_current_volume(name, volume):
        context.volume_name = name
        context.volume = volume
    context.set_current_volume = set_current_volume

    def get_current_volume():
        return context.volume
    context.get_current_volume = get_current_volume

    def get_current_volume_name():
        return context.volume_name
    context.get_current_volume_name = get_current_volume_name



def before_scenario(context, scenario):
    use_fixture(client, context)
    use_fixture(core_api, context)
    use_fixture(volumes, context)
    use_fixture(snapshots, context)
    use_fixture(backups, context)
    use_fixture(replicas, context)
    use_fixture(nodes, context)
    use_fixture(current, context)
    use_fixture(data, context)
