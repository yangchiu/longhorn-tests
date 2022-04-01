import time

from behave import *

import sys
sys.path.append('../../')
import common
import backupstore


def get_current_volume(context):
    volume_name = context.current_volume_name
    volumes = context.client.list_volume()
    for volume in volumes:
        if volume.name == volume_name:
            return volume
    raise RuntimeError('Expect volume existing, but it\'s None!')


@when('create volume "{volume_name}" with size {size:d} MB')
def step_impl(context, volume_name, size):

    volume = common.create_and_check_volume(context.client, volume_name, size=str(size * common.Mi))
    assert volume.restoreRequired is False

    context.current_volume_name = volume_name

@then('attach volume "{volume_name}"')
def step_impl(context, volume_name):

    volume = get_current_volume(context)

    lht_hostId = common.get_self_host_id()
    volume.attach(hostId=lht_hostId)
    volume = common.wait_for_volume_healthy(context.client, volume_name)
    common.check_volume_endpoint(volume)

    # validate soft anti-affinity
    hosts = {}
    for replica in volume.replicas:
        id = replica.hostId
        assert id != ""
        hosts[id] = True
    num_hosts = len(context.client.list_node())
    num_replicas = volume.numberOfReplicas
    if num_hosts >= num_replicas:
        assert len(hosts) == num_replicas
    else:
        assert len(hosts) == num_hosts


@then('write random data "{data_name}" to volume "{volume_name}" with size {size:d} MB')
def step_impl(context, data_name, volume_name, size):

    raise RuntimeError('Fake error!')

    volume = get_current_volume(context)
    common.check_volume_endpoint(volume)

    data = {
        'pos': 0,
        'content': common.generate_random_data(size * common.Mi),
    }
    common.write_volume_data(volume, data)


@then('create backup "{backup_name}" for volume "{volume_name}"')
def step_impl(context, backup_name, volume_name):

    volume = get_current_volume(context)
    snapshot = common.create_snapshot(context.client, volume_name)
    volume.snapshotBackup(name=snapshot.name)
    backup_volume, backup = common.find_backup(context.client, volume_name, snapshot.name)

    context.add_backup(backup_name, backup, snapshot, backup_volume)


@then('find replica "{replica_name}" for backup "{backup_name}"')
def step_impl(context, replica_name, backup_name):

    replica = None
    count = 0
    while not replica and count < 30:
        volume = get_current_volume(context)
        backup_id = context.get_backup_by_name(backup_name).backup.id
        print(f'try {count+1} : backup_id = {backup_id}')
        for status in volume.backupStatus:
            print(status.id)
            if status.id == backup_id:
                print('OK!')
                print(status.replica)
                replica = status.replica
        print(f'replica = {replica}')
        time.sleep(1)
        count += 1
    assert replica
    context.add_replica(replica_name, replica)


@then('find node "{node_name}" for replica "{replica_name}"')
def step_impl(context, node_name, replica_name):

    volume = get_current_volume(context)
    replica = context.get_replica_by_name(replica_name)
    for r in volume.replicas:
        if r.name == replica:
            node = context.client.by_id_node(r.hostId)

    assert node
    context.add_node(node_name, node)


@then('disable node "{node_name}" scheduling')
def step_impl(context, node_name):

    node = context.get_node_by_name(node_name)
    node = context.client.update(node, allowScheduling=False)
    common.wait_for_node_update(context.client, node.id, "allowScheduling", False)


@then('delete replica "{replica_name}"')
def step_impl(context, replica_name):

    volume = get_current_volume(context)
    replica = context.get_replica_by_name(replica_name)
    volume.replicaRemove(name=replica)
    volume = common.wait_for_volume_degraded(context.client, context.current_volume_name)


@then('backup "{backup_name}" should be in error state')
def step_impl(context, backup_name):

    backup = context.get_backup_by_name(backup_name).backup
    backup_id = backup.id

    def backup_failure_predicate(b):
        return b.id == backup_id and "Error" in b.state and b.error != ""
    volume = common.wait_for_backup_state(context.client,
                                          context.current_volume_name,
                                          backup_failure_predicate)


@then('enable node "{node_name}" scheduling')
def step_impl(context, node_name):

    node = context.get_node_by_name(node_name)
    node = context.client.update(node, allowScheduling=True)
    common.wait_for_node_update(context.client, node.id, "allowScheduling", True)


@then('delete backup "{backup_name}"')
def step_impl(context, backup_name):

    volume_name = context.current_volume_name
    backup = context.get_backup_by_name(backup_name).backup
    common.delete_backup(context.client, volume_name, backup.name)


@then('volume "{volume_name}" should have no backup')
def step_impl(context, volume_name):
    volume = common.wait_for_volume_status(context.client, volume_name, "lastBackup", "")
    assert volume.lastBackupAt == ""


@then('wait for backup "{backup_name}" completed')
def step_impl(context, backup_name):

    backup = context.get_backup_by_name(backup_name).backup.name
    volume_name = context.get_backup_by_name(backup_name).volume.name
    snapshot_name = context.get_backup_by_name(backup_name).snapshot.name

    common.wait_for_backup_completion(context.client, volume_name, snapshot_name)

    volume = common.wait_for_volume_status(context.client, volume_name, "lastBackup", backup)
    assert volume.lastBackupAt != ""
