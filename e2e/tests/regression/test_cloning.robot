*** Settings ***
Documentation    Cloning Test Cases

Test Tags    regression

Resource    ../keywords/variables.resource
Resource    ../keywords/common.resource
Resource    ../keywords/volume.resource
Resource    ../keywords/storageclass.resource
Resource    ../keywords/persistentvolumeclaim.resource
Resource    ../keywords/workload.resource
Resource    ../keywords/k8s.resource
Resource    ../keywords/setting.resource
Resource    ../keywords/snapshot.resource
Resource    ../keywords/longhorn.resource
Resource    ../keywords/node.resource
Resource    ../keywords/deployment.resource

Test Setup    Set up test environment
Test Teardown    Cleanup test resources

*** Test Cases ***
Test Cloning Basic
    Given Create storageclass longhorn-test with    dataEngine=${DATA_ENGINE}
    And Create persistentvolumeclaim source-pvc    volume_type=${volume_type}    sc_name=longhorn-test
    And Wait for volume of persistentvolumeclaim source-pvc to be created
    And Wait for volume of persistentvolumeclaim source-pvc detached
    And Create pod source-pod using persistentvolumeclaim source-pvc
    And Wait for pod source-pod running
    And Wait for volume of persistentvolumeclaim source-pvc healthy
    And Write 256 MB data to file data.txt in pod source-pod
    And Record file data.txt checksum in pod source-pod as checksum source-pvc

    When Create persistentvolumeclaim cloned-pvc from persistentvolumeclaim source-pvc    sc_name=longhorn-test
    And Wait for volume of persistentvolumeclaim cloned-pvc to be created
    And Wait for volume of persistentvolumeclaim cloned-pvc cloning to complete
    And Wait for volume of persistentvolumeclaim cloned-pvc detached
    Then Create pod cloned-pod using persistentvolumeclaim cloned-pvc
    And Wait for pod cloned-pod running
    And Wait for volume of persistentvolumeclaim cloned-pvc healthy
    And Check pod cloned-pod file data.txt checksum matches checksum source-pvc

Test Degraded Cloned Volume
    [Documentation]    Issue: https://github.com/longhorn/longhorn/issues/12206
    ...    1. Disable 1 node. Make sure that 2 other nodes are schedulable and as enough storage
    ...    2. Deploy a PVC. Verify that volume is degraded because it need 3 replica but there is only 2 schedulable nodes
    ...    3. Create a cloned-pvc from the previous PVC
    ...    4. Create a pod using cloned-pvc. Verify that the pod is not stuck and Longhorn can attach cloned-pvc
    ...    5. Enable scheduling for the node that you disable at the beginning
    ...       Verify that volume cloned-pvc rebuild and become healthy
    Given Run command
    ...    kubectl cordon ${NODE_0}
    And Run command
    ...    kubectl taint node ${NODE_0} node-role.kubernetes.io/worker=true:NoExecute

    And Create storageclass longhorn-test with    dataEngine=${DATA_ENGINE}
    And Create persistentvolumeclaim source-pvc    sc_name=longhorn-test
    And Wait for volume of persistentvolumeclaim source-pvc to be created
    And Wait for volume of persistentvolumeclaim source-pvc detached
    And Create pod source-pod using persistentvolumeclaim source-pvc
    And Wait for pod source-pod running
    And Wait for volume of persistentvolumeclaim source-pvc degraded
    And Write 256 MB data to file data.txt in pod source-pod
    And Record file data.txt checksum in pod source-pod as checksum source-pvc

    When Create persistentvolumeclaim cloned-pvc from persistentvolumeclaim source-pvc    sc_name=longhorn-test
    And Wait for volume of persistentvolumeclaim cloned-pvc to be created
    And Wait for volume of persistentvolumeclaim cloned-pvc degraded
    And Create pod cloned-pod using persistentvolumeclaim cloned-pvc

    Then Wait for pod cloned-pod running
    And Wait for volume of persistentvolumeclaim cloned-pvc degraded
    And Check pod cloned-pod file data.txt checksum matches checksum source-pvc

    When And Run command
    ...    kubectl uncordon ${NODE_0}
    And Run command
    ...    kubectl taint node ${NODE_0} node-role.kubernetes.io/worker=true:NoExecute-

    Then Wait for volume of persistentvolumeclaim cloned-pvc healthy
    And Check pod cloned-pod file data.txt checksum matches checksum source-pvc

Test Clone Volume With Cordoned Node
    [Documentation]    Issue: https://github.com/longhorn/longhorn/issues/13639
    ...    1. Drain node 0
    ...    2. Create a storageclass and a pvc source-pvc with size 3 Gi
    ...    3. Create a pod to use the pvc, write 2 Gi data to the volume, record the checksum
    ...    4. Delete the pod to detach the volume
    ...    5. Create a pvc cloned-pvc from the source-pvc
    ...    6. Wait for the volume of source-pvc to be attached, it should not be attached to node 0
    ...    7. Wait for the volume of cloned-pvc to be created and attached, it should not be attached to node 0
    ...    8. Wait for the cloning to complete
    ...    9. Create a pod to use the cloned-pvc, and check the data integrity
    Given Drain node 0

    And Create storageclass longhorn-test with    dataEngine=${DATA_ENGINE}
    And Create persistentvolumeclaim source-pvc    storage_size=3Gi    sc_name=longhorn-test
    And Wait for volume of persistentvolumeclaim source-pvc to be created
    And Wait for volume of persistentvolumeclaim source-pvc detached
    And Create pod source-pod using persistentvolumeclaim source-pvc
    And Wait for pod source-pod running
    And Write 2048 MB data to file data.txt in pod source-pod
    And Record file data.txt checksum in pod source-pod as checksum source-pvc

    When Delete pod source-pod
    And Wait for volume of persistentvolumeclaim source-pvc detached

    And Create persistentvolumeclaim cloned-pvc from persistentvolumeclaim source-pvc    sc_name=longhorn-test
    And Wait for volume of persistentvolumeclaim source-pvc attached
    And Volume of persistentvolumeclaim source-pvc should not be attached to node 0
    And Wait for volume of persistentvolumeclaim cloned-pvc to be created
    And Wait for volume of persistentvolumeclaim cloned-pvc attached
    And Volume of persistentvolumeclaim cloned-pvc should not be attached to node 0
    And Wait for volume of persistentvolumeclaim cloned-pvc cloning to complete
    And Wait for volume of persistentvolumeclaim cloned-pvc detached

    Then Create pod cloned-pod using persistentvolumeclaim cloned-pvc
    And Wait for pod cloned-pod running
    And Check pod cloned-pod file data.txt checksum matches checksum source-pvc

Test CSI Clone Respects Node And Disk Selector
    [Documentation]    Issue: https://github.com/longhorn/longhorn/issues/12792
    ...    1. Keep all Longhorn nodes schedulable.
    ...    2. Tag only node 1 and its disk with hosting.
    ...    3. Create a StorageClass with nodeSelector/diskSelector=hosting and strict-local.
    ...    4. Create the source PVC on node 1 and write test data.
    ...    5. Detach the source volume before creating the clone.
    ...    6. Verify the clone replica is scheduled only on node 1.
    ...    7. Verify the clone attachment is not placed on untagged nodes.
    ...    8. Wait for the clone controller to finish and detach the clone.
    ...    9. Attach the cloned PVC to node 1 and verify data integrity.
    [Tags]    clone    csi    scheduling

    Given Set node 1 tags    hosting
    And Set node 1 disks tags    hosting

    And Create storageclass longhorn-hosting-clone with
    ...    numberOfReplicas=1
    ...    dataLocality=strict-local
    ...    nodeSelector=hosting
    ...    diskSelector=hosting
    ...    dataEngine=${DATA_ENGINE}

    And Create persistentvolumeclaim source-pvc
    ...    sc_name=longhorn-hosting-clone
    ...    storage_size=2GiB
    And Wait for volume of persistentvolumeclaim source-pvc to be created

    And Create deployment source-deploy with persistentvolumeclaim source-pvc
    ...    node_selector={"kubernetes.io/hostname":"${NODE_1}"}
    And Wait for deployment source-deploy pods stable
    And Wait for volume of persistentvolumeclaim source-pvc healthy

    And Volume of persistentvolumeclaim source-pvc should have running replicas on node 1
    And Volume of persistentvolumeclaim source-pvc should have no running replica on node 0
    And Volume of persistentvolumeclaim source-pvc should have no running replica on node 2

    And Write 256 MB data to file data.txt in deployment source-deploy
    And Record file data.txt checksum in deployment source-deploy as checksum source-pvc

    When Delete deployment source-deploy
    And Wait for volume of persistentvolumeclaim source-pvc detached

    And Create persistentvolumeclaim cloned-pvc from persistentvolumeclaim source-pvc
    ...    sc_name=longhorn-hosting-clone
    ...    storage_size=2GiB
    And Wait for volume of persistentvolumeclaim cloned-pvc to be created

    Then Wait for volume of persistentvolumeclaim cloned-pvc condition Scheduled to be true
    And Volume of persistentvolumeclaim cloned-pvc should have running replicas on node 1
    And Volume of persistentvolumeclaim cloned-pvc should have no running replica on node 0
    And Volume of persistentvolumeclaim cloned-pvc should have no running replica on node 2

    When Wait for volume of persistentvolumeclaim source-pvc attached
    And Wait for volume of persistentvolumeclaim cloned-pvc attached

    And Volume of persistentvolumeclaim cloned-pvc should not be attached to node 0
    And Volume of persistentvolumeclaim cloned-pvc should not be attached to node 2

    # The clone-controller attachment is removed after cloning finishes.
    # Waiting attached -> detached is a stable completion signal and avoids
    # polling the transient copy-completed-awaiting-healthy cloneStatus.
    And Wait for volume of persistentvolumeclaim cloned-pvc detached

    Then Create deployment cloned-deploy with persistentvolumeclaim cloned-pvc
    ...    node_selector={"kubernetes.io/hostname":"${NODE_1}"}
    And Wait for deployment cloned-deploy pods stable
    And Wait for volume of persistentvolumeclaim cloned-pvc healthy
    And Check deployment cloned-deploy file data.txt checksum matches checksum source-pvc

Test Pod Mount Before Cloning Complete
    [Documentation]
    ...    Issue: https://github.com/longhorn/longhorn/issues/13335
    ...    1. Clone a volume into a new PVC.
    ...    2. Immediately, before the cloning completes, create a pod using
    ...       the cloned PVC.
    ...    3. Wait for the pod to be running.
    Given Create storageclass longhorn-test with    dataEngine=${DATA_ENGINE}
    And Create persistentvolumeclaim source-pvc    storage_size=3Gi    sc_name=longhorn-test
    And Wait for volume of persistentvolumeclaim source-pvc to be created
    And Wait for volume of persistentvolumeclaim source-pvc detached
    And Create pod source-pod using persistentvolumeclaim source-pvc
    And Wait for pod source-pod running
    And Write 2048 MB data to file data.txt in pod source-pod
    And Record file data.txt checksum in pod source-pod as checksum source-pvc

    When Create persistentvolumeclaim cloned-pvc from persistentvolumeclaim source-pvc    sc_name=longhorn-test
    And Wait for volume of persistentvolumeclaim cloned-pvc to be created
    And Wait for volume of persistentvolumeclaim cloned-pvc attached
    Then Create pod cloned-pod using persistentvolumeclaim cloned-pvc
    And Wait for pod cloned-pod running
    And Check pod cloned-pod file data.txt checksum matches checksum source-pvc

Test Clone Volume Attaches To Consumer Pod On Different Node From Replica
    [Documentation]    Issue: https://github.com/longhorn/longhorn/issues/13335
    ...    Bug: A CSI clone with a single replica can get wedged when the clone's
    ...    replica lands on a node different from the consuming pod's node.
    ...    The clone-controller attaches the volume on the replica's node,
    ...    finishes the copy, but then never hands the attachment over to the
    ...    consumer's node, so the pod stays stuck with
    ...    "volume ... is not ready for workloads" and the volume eventually
    ...    detaches from the clone node without ever serving the pod.
    ...    Note: the StorageClass nodeSelector/diskSelector only control where
    ...    Longhorn schedules the volume's replica(s); they have no effect on
    ...    Kubernetes pod scheduling. Conversely, the deployment's
    ...    node_selector only controls which node the pod (and therefore the
    ...    Longhorn volume attachment/engine) lands on; it has no effect on
    ...    replica placement. Using both together lets this test force the
    ...    replica and the consuming pod onto different nodes.
    ...    Note: the source data must be large enough that the clone copy
    ...    takes noticeably longer than pod scheduling + the CSI attach call.
    ...    Otherwise the consumer pod's attach request would race behind an
    ...    already-finished clone, and the "attach requested before clone
    ...    completes" scenario from the bug report would never actually be
    ...    exercised, i.e. the test would pass trivially without reproducing
    ...    the timing that triggers the bug.
    ...    1. Tag node 1 and its disk so the source and cloned volume replica
    ...       are scheduled only on node 1.
    ...    2. Create a 1-replica StorageClass restricted to node 1 via
    ...       nodeSelector/diskSelector.
    ...    3. Create the source PVC and write test data to it on node 1.
    ...    4. Create a clone PVC from the source PVC using the same
    ...       StorageClass, so its replica also lands on node 1.
    ...    5. Immediately create a consumer pod for the clone on node 2, a
    ...       different node from the clone's replica, mimicking VolSync
    ...       mounting the clone as soon as it is created. Because the copy
    ...       takes a while, the pod's attach request should land while the
    ...       clone is still copying.
    ...    6. Verify the clone actually reaches the copy-completed-awaiting-
    ...       healthy transient state (proving the race above was captured),
    ...       the pod successfully attaches and runs (not stuck waiting for
    ...       workloads), and the data is intact.
    Given Set node 1 tags    hosting
    And Set node 1 disks tags    hosting

    And Create storageclass longhorn-hosting-clone with
    ...    numberOfReplicas=1
    ...    nodeSelector=hosting
    ...    diskSelector=hosting
    ...    dataEngine=${DATA_ENGINE}

    And Create persistentvolumeclaim source-pvc
    ...    sc_name=longhorn-hosting-clone
    ...    storage_size=25GiB
    And Wait for volume of persistentvolumeclaim source-pvc to be created

    And Create deployment source-deploy with persistentvolumeclaim source-pvc
    ...    node_selector={"kubernetes.io/hostname":"${NODE_1}"}
    And Wait for volume of persistentvolumeclaim source-pvc healthy
    And Volume of persistentvolumeclaim source-pvc should have running replicas on node 1
    # Large enough that the copy takes noticeably longer than pod scheduling
    # and the CSI attach call, so the consumer pod's attach request in step 5
    # below reliably lands while the clone is still in progress.
    And Write 20480 MB data to file data.txt in deployment source-deploy
    And Record file data.txt checksum in deployment source-deploy as checksum source-pvc

    And Create persistentvolumeclaim cloned-pvc from persistentvolumeclaim source-pvc
    ...    sc_name=longhorn-hosting-clone
    ...    storage_size=25GiB
    And Wait for volume of persistentvolumeclaim cloned-pvc to be created

    Then Create deployment cloned-deploy with persistentvolumeclaim cloned-pvc
    ...    node_selector={"kubernetes.io/hostname":"${NODE_2}"}

    # This proves the consumer pod above was created, and its attach was
    # requested, while the clone was still copying: the clone must still be
    # running (or just finishing) to be caught transitioning through
    # copy-completed-awaiting-healthy here instead of already being done.
    #And Wait for volume of persistentvolumeclaim cloned-pvc cloning to complete
    And Volume of persistentvolumeclaim cloned-pvc should have running replicas on node 1

    And Wait for deployment cloned-deploy pods stable
    And Wait for volume of persistentvolumeclaim cloned-pvc healthy
    And Volume of persistentvolumeclaim cloned-pvc should not be attached to node 1
    And Volume of persistentvolumeclaim cloned-pvc should be attached to node 2
    And Check deployment cloned-deploy file data.txt checksum matches checksum source-pvc
