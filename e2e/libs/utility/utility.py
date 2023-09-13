from kubernetes import config, client, dynamic
from kubernetes.client.rest import ApiException
from kubernetes.stream import stream
from longhorn import from_env
import string
import random
import os
import socket
import time
import yaml
import logging

RETRY_COUNTS = 150
RETRY_INTERVAL = 1
POD_WAIT_INTERVAL = 1
POD_WAIT_TIMEOUT = 240
WAIT_FOR_POD_STABLE_MAX_RETRY = 90

def generate_volume_name():
    return "vol-" + \
        ''.join(random.choice(string.ascii_lowercase + string.digits)
                for _ in range(6))

def init_k8s_api_client():
    if os.getenv('LONGHORN_CLIENT_URL'):
        # for develop or debug, run test in local environment
        config.load_kube_config()
        logging.info("initialize out-of-cluster k8s api client")
    else:
        # for ci, run test in in-cluster environment
        config.load_incluster_config()
        logging.info("initialize in-cluster k8s api client")

def list_nodes():
    core_api = client.CoreV1Api()
    obj = core_api.list_node()
    nodes = []
    for item in obj.items:
        if 'node-role.kubernetes.io/control-plane' not in item.metadata.labels and \
                'node-role.kubernetes.io/master' not in item.metadata.labels:
            nodes.append(item.metadata.name)
    return sorted(nodes)

def wait_for_cluster_ready():
    core_api = client.CoreV1Api()
    for i in range(RETRY_COUNTS):
        try:
            resp = core_api.list_node()
            ready = True
            for item in resp.items:
                for condition in item.status.conditions:
                    if condition.type == 'Ready' and condition.status != 'True':
                        ready = False
                        break
            if ready:
                break
        except Exception as e:
            logging.warn(f"list node error: {e}")
        time.sleep(RETRY_INTERVAL)
    assert ready, f"expect cluster's ready but it isn't {resp}"

def get_node(index):
    nodes = list_nodes()
    return nodes[int(index)]

def apply_cr(manifest_dict):
    dynamic_client = dynamic.DynamicClient(client.api_client.ApiClient())
    api_version = manifest_dict.get("apiVersion")
    kind = manifest_dict.get("kind")
    resource_name = manifest_dict.get("metadata").get("name")
    namespace = manifest_dict.get("metadata").get("namespace")
    crd_api = dynamic_client.resources.get(api_version=api_version, kind=kind)

    try:
        crd_api.get(namespace=namespace, name=resource_name)
        crd_api.patch(body=manifest_dict,
                      content_type="application/merge-patch+json")
        logging.info(f"{namespace}/{resource_name} patched")
    except dynamic.exceptions.NotFoundError:
        crd_api.create(body=manifest_dict, namespace=namespace)
        logging.info(f"{namespace}/{resource_name} created")

def apply_cr_from_yaml(filepath):
    with open(filepath, 'r') as f:
        manifest_dict = yaml.safe_load(f)
        apply_cr(manifest_dict)

def get_cr(group, version, namespace, plural, name):
    api = client.CustomObjectsApi()
    try:
        resp = api.get_namespaced_custom_object(group, version, namespace, plural, name)
        return resp
    except ApiException as e:
        print("Exception when calling CustomObjectsApi->get_namespaced_custom_object: %s\n" % e)

def filter_cr(group, version, namespace, plural, field_selector="", label_selector=""):
    api = client.CustomObjectsApi()
    try:
        resp = api.list_namespaced_custom_object(group, version, namespace, plural, field_selector=field_selector, label_selector=label_selector)
        return resp
    except ApiException as e:
        print("Exception when calling CustomObjectsApi->list_namespaced_custom_object: %s\n" % e)

def wait_delete_pod(pod_uid, namespace='default'):
    api = client.CoreV1Api()
    for i in range(RETRY_COUNTS):
        ret = api.list_namespaced_pod(namespace=namespace)
        found = False
        for item in ret.items:
            if item.metadata.uid == pod_uid:
                found = True
                break
        if not found:
            break
        time.sleep(RETRY_INTERVAL)
    assert not found

def wait_delete_ns(name):
    api = client.CoreV1Api()
    for i in range(RETRY_COUNTS):
        ret = api.list_namespace()
        found = False
        for item in ret.items:
            if item.metadata.name == name:
                found = True
                break
        if not found:
            break
        time.sleep(RETRY_INTERVAL)
    assert not found

def create_deployment(filepath):
    with open(filepath, 'r') as f:
        namespace = 'default'
        manifest_dict = yaml.safe_load(f)
        api = client.AppsV1Api()
        try:
            deployment = api.create_namespaced_deployment(
                namespace=namespace,
                body=manifest_dict)
            print(deployment)

            deployment_name = deployment.metadata.name
            replicas = deployment.spec.replicas

            for i in range(RETRY_COUNTS):
                deployment = api.read_namespaced_deployment(
                    name=deployment_name,
                    namespace=namespace)
                # deployment is none if deployment is not yet created
                if deployment is not None and \
                    deployment.status.ready_replicas == replicas:
                    break
                time.sleep(RETRY_INTERVAL)

            assert deployment.status.ready_replicas == replicas

        except Exception as e:
            print(f"Exception when create deployment: {e}")
    return deployment_name

def delete_deployment(name, namespace='default'):
    api = client.AppsV1Api()

    try:
        api.delete_namespaced_deployment(
            name=name,
            namespace=namespace,
            grace_period_seconds=0)
    except ApiException as e:
        assert e.status == 404

    for i in range(RETRY_COUNTS):
        resp = api.list_namespaced_deployment(namespace=namespace)
        deleted = True
        for item in resp.items:
            if item.metadata.name == name:
                deleted = False
                break
        if deleted:
            break
        time.sleep(RETRY_INTERVAL)
    assert deleted

def create_statefulset(filepath):
    with open(filepath, 'r') as f:
        namespace = 'default'
        manifest_dict = yaml.safe_load(f)
        api = client.AppsV1Api()
        try:
            statefulset = api.create_namespaced_stateful_set(
                body=manifest_dict,
                namespace=namespace)

            statefulset_name = statefulset.metadata.name
            replicas = statefulset.spec.replicas

            for i in range(RETRY_COUNTS):
                statefulset = api.read_namespaced_stateful_set(
                    name=statefulset_name,
                    namespace=namespace)
                # statefulset is none if statefulset is not yet created
                if statefulset is not None and \
                    statefulset.status.ready_replicas == replicas:
                    break
                time.sleep(RETRY_INTERVAL)

            assert statefulset.status.ready_replicas == replicas

        except Exception as e:
            print(f"Exception when create statefulset: {e}")
    return statefulset_name

def delete_statefulset(name, namespace='default'):
    api = client.AppsV1Api()

    try:
        api.delete_namespaced_stateful_set(
            name=name,
            namespace=namespace,
            grace_period_seconds=0)
    except ApiException as e:
        assert e.status == 404

    for i in range(RETRY_COUNTS):
        resp = api.list_namespaced_stateful_set(namespace=namespace)
        deleted = True
        for item in resp.items:
            if item.metadata.name == name:
                deleted = False
                break
        if deleted:
            break
        time.sleep(RETRY_INTERVAL)
    assert deleted

def create_pvc(filepath):
    with open(filepath, 'r') as f:
        namespace = 'default'
        manifest_dict = yaml.safe_load(f)
        api = client.CoreV1Api()
        try:
            pvc = api.create_namespaced_persistent_volume_claim(
                body=manifest_dict,
                namespace=namespace)
        except Exception as e:
            print(f"Exception when create pvc: {e}")
    return pvc.metadata.name


def delete_pvc(name, namespace='default'):
    api = client.CoreV1Api()

    try:
        api.delete_namespaced_persistent_volume_claim(
            name=name,
            namespace=namespace,
            grace_period_seconds=0)
    except ApiException as e:
        assert e.status == 404

    for i in range(RETRY_COUNTS):
        resp = api.list_namespaced_persistent_volume_claim(namespace=namespace)
        deleted = True
        for item in resp.items:
            if item.metadata.name == name:
                deleted = False
                break
        if deleted:
            break
        time.sleep(RETRY_INTERVAL)
    assert deleted

def get_workload_pod_names(workload_name):
    api = client.CoreV1Api()
    label_selector = f"app={workload_name}"
    pod_list = api.list_namespaced_pod(
        namespace="default",
        label_selector=label_selector)
    pod_names = []
    for pod in pod_list.items:
        pod_names.append(pod.metadata.name)
    return pod_names

def get_workload_pods(workload_name):
    api = client.CoreV1Api()
    label_selector = f"app={workload_name}"
    resp = api.list_namespaced_pod(
        namespace="default",
        label_selector=label_selector)
    return resp.items

def get_workload_volume_name(workload_name):
    get_workload_pvc_name(workload_name)
    pvc = api.read_namespaced_persistent_volume_claim(
        name=pvc_name, namespace='default')
    return pvc.spec.volume_name

def get_workload_pvc_name(workload_name):
    api = client.CoreV1Api()
    pod = get_workload_pods(workload_name)[0]
    print(f"pod = {pod}")
    for volume in pod.spec.volumes:
        if volume.name == 'pod-data':
            pvc_name = volume.persistent_volume_claim.claim_name
            break
    assert pvc_name
    return pvc_name

def write_pod_random_data(pod_name, size_in_mb, path="/data/random-data"):
    api = client.CoreV1Api()
    write_cmd = [
        '/bin/sh',
        '-c',
        f"dd if=/dev/urandom of={path} bs=1M count={size_in_mb} status=none;\
          md5sum {path} | awk \'{{print $1}}\'"
    ]
    return stream(
        api.connect_get_namespaced_pod_exec, pod_name, 'default',
        command=write_cmd, stderr=True, stdin=False, stdout=True,
        tty=False)

def keep_writing_pod_data(pod_name, size_in_mb=256, path="/data/overwritten-data"):
    api = client.CoreV1Api()
    write_cmd = [
        '/bin/sh',
        '-c',
        f"while true; do dd if=/dev/urandom of={path} bs=1M count={size_in_mb} status=none; done > /dev/null 2> /dev/null &"
    ]
    logging.warn("before keep_writing_pod_data")
    res = stream(
        api.connect_get_namespaced_pod_exec, pod_name, 'default',
        command=write_cmd, stderr=True, stdin=False, stdout=True,
        tty=False)
    logging.warn("keep_writing_pod_data return")
    return res

def check_pod_data(pod_name, checksum, path="/data/random-data"):
    api = client.CoreV1Api()
    cmd = [
        '/bin/sh',
        '-c',
        f"md5sum {path} | awk \'{{print $1}}\'"
    ]
    _checksum = stream(
        api.connect_get_namespaced_pod_exec, pod_name, 'default',
        command=cmd, stderr=True, stdin=False, stdout=True,
        tty=False)
    print(f"get {path} checksum = {_checksum},\
                expected checksum = {checksum}")
    assert _checksum == checksum

def wait_for_workload_pod_stable(workload_name):
    stable_pod = None
    wait_for_stable_retry = 0
    for _ in range(POD_WAIT_TIMEOUT):
        pods = get_workload_pods(workload_name)
        for pod in pods:
            if pod.status.phase == "Running":
                if stable_pod is None or \
                        stable_pod.status.start_time != pod.status.start_time:
                    stable_pod = pod
                    wait_for_stable_retry = 0
                    break
                else:
                    wait_for_stable_retry += 1
                    if wait_for_stable_retry == WAIT_FOR_POD_STABLE_MAX_RETRY:
                        return stable_pod
        time.sleep(POD_WAIT_INTERVAL)
    assert False

def get_mgr_ips():
    ret = client.CoreV1Api().list_pod_for_all_namespaces(
        label_selector="app=longhorn-manager",
        watch=False)
    mgr_ips = []
    for i in ret.items:
        mgr_ips.append(i.status.pod_ip)
    return mgr_ips

def get_longhorn_client():
    if os.getenv('LONGHORN_CLIENT_URL'):
        logging.info(f"initialize longhorn api client from LONGHORN_CLIENT_URL")
        # for develop or debug
        # manually expose longhorn client
        # to access longhorn manager in local environment
        longhorn_client_url = os.getenv('LONGHORN_CLIENT_URL')
        for i in range(RETRY_COUNTS):
            try:
                longhorn_client = from_env(url=f"{longhorn_client_url}/v1/schemas")
                return longhorn_client
            except Exception as e:
                logging.info(f"get longhorn client error: {e}")
                time.sleep(RETRY_INTERVAL)
    else:
        logging.info(f"initialize longhorn api client from longhorn manager")
        # for ci, run test in in-cluster environment
        # directly use longhorn manager cluster ip
        for i in range(RETRY_COUNTS):
            try:
                config.load_incluster_config()
                ips = get_mgr_ips()
                # check if longhorn manager port is open before calling get_client
                for ip in ips:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    mgr_port_open = sock.connect_ex((ip, 9500))
                    if mgr_port_open == 0:
                        longhorn_client = from_env(url=f"http://{ip}:9500/v1/schemas")
                        return longhorn_client
            except Exception as e:
                logging.info(f"get longhorn client error: {e}")
                time.sleep(RETRY_INTERVAL)

def get_test_pod_running_node():
    if "NODE_NAME" in os.environ:
        return os.environ["NODE_NAME"]
    else:
        return get_node(0)

def get_test_pod_not_running_node():
    nodes = list_nodes()
    test_pod_running_node = get_test_pod_running_node()
    for node in nodes:
        if node != test_pod_running_node:
            return node

def get_test_case_namespace(test_name):
    return test_name.lower().replace(' ', '-')