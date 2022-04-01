from behave import *

import sys
sys.path.append('../../')
import common
import backupstore


@when('set backup store to s3')
def step_impl(context):
    backupstore.set_backupstore_s3(context.client)
    backup_target = backupstore.backupstore_get_backup_target(context.client)
    backup_secret = backupstore.backupstore_get_secret(context.client)
    print(f'set backup store to target = {backup_target}, secret = {backup_secret}')


@then('longhorn manager pods annotation should not have "{key}"')
def step_impl(context, key):
    common.wait_for_pod_annotation(context.core_api, 'app=longhorn-manager', key, None)


@then('replica instance manager pods annotation should not have "{key}"')
def step_impl(context, key):
    common.wait_for_pod_annotation(context.core_api, 'longhorn.io/instance-manager-type=replica', key, None)


@then('add key "{key}" value "{value}" to secret')
def step_impl(context, key, value):
    secret_name = backupstore.backupstore_get_secret(context.client)
    secret = context.core_api.read_namespaced_secret(name=secret_name, namespace='longhorn-system')

    secret.data[key] = value
    res = context.core_api.patch_namespaced_secret(name=secret_name, namespace='longhorn-system', body=secret)
    print(f'patch secret.data[{key}] to {res.data[key]}')

    _secret = context.core_api.read_namespaced_secret(name=secret_name, namespace='longhorn-system')
    print(f'set secret.data[{key}] to {secret.data[key]}')


@then('longhorn manager pods annotation should have key "{key}" value "{value}"')
def step_impl(context, key, value):
    common.wait_for_pod_annotation(context.core_api, 'app=longhorn-manager', key, value)


@then('replica instance manager pods annotation should have key "{key}" value "{value}"')
def step_impl(context, key, value):
    common.wait_for_pod_annotation(context.core_api, 'longhorn.io/instance-manager-type=replica', key, value)


@then('remove key "{key}" from secret')
def step_impl(context, key):
    secret_name = backupstore.backupstore_get_secret(context.client)
    body = [{"op": "remove", "path": f"/data/{key}"}]
    context.core_api.patch_namespaced_secret(name=secret_name, namespace='longhorn-system', body=body)
