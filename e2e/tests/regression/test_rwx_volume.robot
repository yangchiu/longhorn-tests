*** Settings ***
Documentation    RWX Volume Test Cases

Test Tags    regression    rwx

Resource    ../keywords/variables.resource
Resource    ../keywords/common.resource
Resource    ../keywords/deployment.resource
Resource    ../keywords/daemonset.resource
Resource    ../keywords/statefulset.resource
Resource    ../keywords/storageclass.resource
Resource    ../keywords/persistentvolumeclaim.resource
Resource    ../keywords/workload.resource
Resource    ../keywords/host.resource
Resource    ../keywords/k8s.resource
Resource    ../keywords/sharemanager.resource
Resource    ../keywords/longhorn.resource
Resource    ../keywords/setting.resource
Resource    ../keywords/metrics.resource

Test Setup    Set up test environment
Test Teardown    Cleanup test resources

*** Variables ***
${RWX_UNINTERRUPTIBLE_SLEEP_CHECK_DURATION}    30
${RWX_FAST_FAILOVER_MAX_OUTAGE_SECONDS}    60

*** Test Cases ***

Test RWX Volume Does Not Cause Process Uninterruptible Sleep
    [Tags]    volume
    [Documentation]    Test that RWX volume with multiple pods writing to the same file
    ...                does not cause processes to get stuck in uninterruptible sleep state.
    ...
    ...                Issue: https://github.com/longhorn/longhorn/issues/11907
    ...
    ...                Steps:
    ...                1. Create a single node cluster (cordon nodes 0 and 1)
    ...                2. Create a RWX volume
    ...                3. Create a deployment with 6 replicas, all writing to the same file
    ...                4. Check every minute for 30 minutes that no processes are stuck in D state
    ...                   (A process is considered stuck if it remains in D state for 30+ seconds)
    ...                5. Verify that all replicas remain accessible and working

    # Create a single-node environment by cordoning nodes 0 and 1
    Given Cordon node 0
    And Cordon node 1
    
    And Create storageclass longhorn-test with    dataEngine=${DATA_ENGINE}    nfsOptions=vers=4.0,noresvport,softerr,timeo=600,retrans=5    numberOfReplicas=1
    And Create persistentvolumeclaim 0    volume_type=RWX    sc_name=longhorn-test
    And Create deployment 0 with persistentvolumeclaim 0    replicaset=6    args=sleep 10; touch /data/index.html; while true; do echo "$(date) $(hostname)" >> /data/index.html; sleep 1; done;
    And Wait for volume of deployment 0 healthy

    # Continuously check for uninterruptible sleep processes every minute for the specified duration
    ${UNEXPECTED_D_STATE} =    Set Variable    ${False}
    ${i} =    Set Variable    ${0}
    WHILE    ${i} < ${RWX_UNINTERRUPTIBLE_SLEEP_CHECK_DURATION}
        ${current_check} =    Evaluate    ${i} + 1
        Log To Console    Checking for uninterruptible sleep processes (${current_check}/${RWX_UNINTERRUPTIBLE_SLEEP_CHECK_DURATION})...
        
        # Check node 2 (the only schedulable node) for processes in D state
        # We check for processes related to writing to /data/index.html
        ${has_d_state} =    Run command on node 2 and get output    pgrep -f 'echo.*/data/index.html' | xargs -r ps --no-headers -o pid,stat,command -p    D
        
        IF    ${has_d_state}
            Log To Console    D-state process detected, rechecking to see if stuck...
            ${UNEXPECTED_D_STATE} =    Set Variable    ${True}
            # Don't increment i, recheck on next iteration
        ELSE
            ${UNEXPECTED_D_STATE} =    Set Variable    ${False}
            ${i} =    Evaluate    ${i} + 1
        END
        
        # Wait 1 minute before next check
        Sleep    60
    END
    
    # If we found D-state in the last check, it's considered stuck
    IF    ${UNEXPECTED_D_STATE}
        ${error_output} =    Run command on node 2 and get output string    pgrep -f 'echo.*/data/index.html' | xargs -r ps --no-headers -o pid,stat,command -p
        Log To Console    Process stuck in D-state detected: ${error_output}
        Sleep    ${RETRY_COUNT}
        Fail    Process stuck in uninterruptible sleep (D state) detected on node 2: ${error_output}
    END

    # Verify all replicas are still working properly
    Then Wait for deployment 0 pods stable
    And Check all deployment 0 replica pods are working
    And Check deployment 0 pods not restarted
    And Check deployment 0 pods not recreated

Test ShareManager Status Current Image After Fresh Install
    [Tags]    sharemanager
    [Documentation]    Verify that status.currentImage in the ShareManager CR is correctly set
    ...                after a fresh Longhorn installation.
    ...
    ...                - Issue: https://github.com/longhorn/longhorn/issues/11203
    ...                Steps:
    ...                - 1. Create a RWX storage class and PVC
    ...                - 2. Create a deployment consuming the RWX PVC
    ...                - 3. Wait for the volume to become healthy and the share manager pod to be running
    ...                - 4. Assert that the ShareManager CR status.currentImage matches spec.image
    ...                - 5. Assert that the share manager pod container image matches spec.image
    Given Create storageclass longhorn-test with    dataEngine=${DATA_ENGINE}
    And Create persistentvolumeclaim 0    volume_type=RWX    sc_name=longhorn-test
    And Create deployment 0 with persistentvolumeclaim 0
    And Wait for volume of deployment 0 healthy
    When Wait for sharemanager pod of deployment 0 running
    Then Assert sharemanager current image of deployment 0 matches spec image
    And Assert sharemanager pod container image of deployment 0 matches spec image

Test ShareManager Status Current Image After Upgrade
    [Tags]    upgrade    sharemanager
    [Documentation]    Verify that status.currentImage is preserved after a Longhorn upgrade
    ...                and is updated only once the share manager pod is restarted.
    ...
    ...                - Issue: https://github.com/longhorn/longhorn/issues/11203
    ...
    ...                - 1. Uninstall Longhorn and install the stable version
    ...                - 2. Create a RWX PVC and a deployment consuming it
    ...                - 3. Wait for the volume to become healthy and the share manager pod to be running
    ...                - 4. Record the pre-upgrade ShareManager spec.image as the old image
    ...                - 5. Upgrade Longhorn to the custom version
    ...                - 6. Assert that status.currentImage still reflects the old image
    ...                     (share manager pod has not been restarted yet)
    ...                - 7. Scale down the deployment to trigger share manager pod termination
    ...                - 8. Wait for the share manager pod to be fully deleted
    ...                - 9. Scale up the deployment to trigger share manager pod recreation
    ...                - 10. Wait for the new share manager pod to be running
    ...                - 11. Assert that status.currentImage now matches spec.image (new version)
    ...                - 12. Assert that the share manager pod container image matches spec.image
    IF    '${DATA_ENGINE}' == 'v2'
        Skip    v2 volume doesn't support live upgrade
    END

    ${LONGHORN_STABLE_VERSION}=    Get Environment Variable    LONGHORN_STABLE_VERSION    default=''
    IF    '${LONGHORN_STABLE_VERSION}' == ''
        Skip    LONGHORN_STABLE_VERSION not set - required for upgrade test
    END

    Given setting deleting-confirmation-flag is set to true
    And Uninstall Longhorn
    And Check Longhorn CRD removed

    When Install Longhorn stable version
    And Create storageclass longhorn-test with    dataEngine=v1
    And Create persistentvolumeclaim 0    volume_type=RWX    sc_name=longhorn-test
    And Create deployment 0 with persistentvolumeclaim 0
    And Wait for volume of deployment 0 healthy
    And Wait for sharemanager pod of deployment 0 running

    # Record the pre-upgrade image — status.currentImage and spec.image are equal
    # on a freshly installed system; recording spec.image captures the stable-version image.
    ${old_sharemanager_image} =    get sharemanager spec image of deployment 0

    When Upgrade Longhorn to custom version

    # The share manager pod has not been restarted yet, so status.currentImage must
    # still reflect the pre-upgrade (old) image.
    Then Assert sharemanager current image of deployment 0 is ${old_sharemanager_image}

    # Restart the share manager pod by cycling the workload.
    When Scale down deployment 0 to detach volume
    And Wait for sharemanager pod of deployment 0 deleted
    And Scale up deployment 0 to attach volume
    And Wait for sharemanager pod of deployment 0 running

    # After the pod is recreated with the new image, status.currentImage must reflect
    # spec.image (the post-upgrade image).
    Then Assert sharemanager current image of deployment 0 matches spec image
    And Assert sharemanager pod container image of deployment 0 matches spec image

Test RWX Failover And Auto Salvage When Volume Is Faulted
    [Tags]    rwx-fast-failover    node-down
    [Documentation]    If the volume is faulted, we don't need to have RWX fast failover
    ...    Issue: https://github.com/longhorn/longhorn/issues/9089
    ...
    ...    1. Enable RWX fast failover setting
    ...    2. Deploy a workload which uses a RWX PVC
    ...    3. Reduce the number of replicas to 1. Delete 2 replicas not on the same node as the share manager pod
    ...    4. Record the CPU usage
    ...    5. Turn off the node of the share manager pod
    ...    6. Volume stay in faulted. Share manager pod is recreated but then error and deleted. the CPU usage is still small
    ...    7. Turn on the node of the share-manager pod
    ...    8. Volume is salvaged and should not be stuck in auto-salvage loop forever. Share manager pod is recreated and become running. CPU usage still is small
    Given Setting rwx-volume-fast-failover is set to true
    And Setting auto-salvage is set to true
    And Create storageclass longhorn-test with    numberOfReplicas=3    dataEngine=${DATA_ENGINE}
    And Create statefulset 0     volume_type=RWX    sc_name=longhorn-test
    And Wait for volume of statefulset 0 healthy
    And Update volume of statefulset 0 replica count to 1
    And Delete replica of statefulset 0 volume on all replica node
    And Write 1 MB data to file data.bin in statefulset 0
    And Get Longhorn components resource usage

    When Power off volume node of statefulset 0
    Then Check volume of statefulset 0 kept in faulted
    And Check Longhorn components resource usage

    When Power on off nodes
    Then Wait for volume of statefulset 0 healthy
    And Check statefulset 0 data in file data.bin is intact
    And Wait for sharemanager pod of statefulset 0 running
    And Check Longhorn components resource usage

*** Keywords ***
RWX Fast Failover IO Outage Duration
    [Arguments]    ${nfs_options}
    [Documentation]    Verify that when the node running the share-manager pod for a RWX
    ...    volume goes down, IO only hangs until the share-manager pod is recreated on
    ...    another node, and the total outage (including the NFS grace period) stays
    ...    under ${RWX_FAST_FAILOVER_MAX_OUTAGE_SECONDS} seconds.
    ...
    ...    Steps:
    ...    1. Enable rwx-volume-fast-failover feature.
    ...    2. Create 1 RWX volume that is attached to node X (share-manager node) and run
    ...       an app pod with the RWX volume on node Y. Execute
    ...       ( exec 7<>/data/testfile-0; flock -x 7; while date +%s | dd conv=fsync >&7 ; do sleep 1; done; )
    ...       in the app pod, which appends the current epoch second to the file roughly
    ...       once per second.
    ...    3. Power off node X. Wait for the share-manager pod to be recreated on another node.
    ...    4. IO to the RWX volume hangs until the share-manager pod replacement is
    ...       successfully created on another node.
    ...    5. Outage, including grace period, should be less than 60 seconds. This is
    ...       verified by reading the appended epoch seconds back from the testfile: the
    ...       gap between two consecutive numbers will be larger than 1 if there was an
    ...       outage.
    Given Setting rwx-volume-fast-failover is set to true
    And Create storageclass longhorn-test with    dataEngine=${DATA_ENGINE}    nfsOptions=${nfs_options}
    And Create persistentvolumeclaim 0    volume_type=RWX    sc_name=longhorn-test
    And Create deployment 0 with persistentvolumeclaim 0
    ...    replicaset=1
    ...    node_selector={"kubernetes.io/hostname":"${NODE_1}"}
    ...    args=exec 7<>/data/testfile-$(hostname -s); flock -x 7; while date +%s | dd conv=fsync >&7 ; do sleep 1; done;
    And Wait for volume of deployment 0 healthy
    And Wait for sharemanager pod of deployment 0 running

    When Power off volume node of deployment 0
    Then Wait for sharemanager pod of deployment 0 running

    ${pod_name} =    Get pod name of deployment 0
    ${content} =    Run command    kubectl exec ${pod_name} -- sh -c "cat /data/testfile-*"
    ${nums} =    Evaluate    [int(x) for x in $content.split()]
    ${max_gap} =    Evaluate    max([b - a for a, b in zip($nums, $nums[1:])]) if len($nums) > 1 else 0
    Should Be True    ${max_gap} <= ${RWX_FAST_FAILOVER_MAX_OUTAGE_SECONDS}
    ...    IO outage of ${max_gap}s exceeded threshold ${RWX_FAST_FAILOVER_MAX_OUTAGE_SECONDS}s for deployment 0

    When Power on off nodes
    Then Wait for volume of deployment 0 healthy

RWX Fast Failover With DaemonSet And Auto Delete Pod Disabled
    [Arguments]    ${nfs_options}
    [Documentation]    Verify that when auto-delete-pod-when-volume-detached-unexpectedly
    ...    is disabled, a RWX volume's share-manager pod still fails over correctly, and
    ...    the other active daemonset pods (on nodes that were not powered off) do not
    ...    run into errors.
    ...
    ...    Steps:
    ...    1. Enable rwx-volume-fast-failover feature.
    ...    2. Create a daemonset with a RWX volume, and disable Automatically Delete
    ...       Workload Pod when The Volume Is Detached Unexpectedly.
    ...    3. Power off the node where share-manager is running. Once the share-manager
    ...       pod is recreated on a different node, check:
    ...       - The other active pods should not run into errors
    ...       - Outage, including grace period, should be less than 60 seconds.
    Given Setting rwx-volume-fast-failover is set to true
    And Setting auto-delete-pod-when-volume-detached-unexpectedly is set to false
    And Create storageclass longhorn-test with    dataEngine=${DATA_ENGINE}    nfsOptions=${nfs_options}
    And Create persistentvolumeclaim 0    volume_type=RWX    sc_name=longhorn-test
    And Create daemonset 0 with persistentvolumeclaim 0
    ...    args=exec 7<>/data/testfile-$(hostname -s); flock -x 7; while date +%s | dd conv=fsync >&7 ; do sleep 1; done;
    And Wait for volume of daemonset 0 healthy
    And Wait for sharemanager pod of daemonset 0 running

    When Power off volume node of daemonset 0
    Then Wait for sharemanager pod of daemonset 0 running

    # Check IO continuity across all remaining (non-powered-off) daemonset pods,
    # since they all share the same RWX volume and are affected by the failover.
    # Pods on the powered off node may temporarily fail to exec, so ignore those.
    ${pod_names} =    Get pod names of daemonset 0
    FOR    ${pod_name}    IN    @{pod_names}
        ${status}    ${content} =    Run Keyword And Ignore Error
        ...    Run command    kubectl exec ${pod_name} -- sh -c "cat /data/testfile-*"
        IF    '${status}' == 'PASS'
            ${nums} =    Evaluate    [int(x) for x in $content.split()]
            ${max_gap} =    Evaluate    max([b - a for a, b in zip($nums, $nums[1:])]) if len($nums) > 1 else 0
            Should Be True    ${max_gap} <= ${RWX_FAST_FAILOVER_MAX_OUTAGE_SECONDS}
            ...    IO outage of ${max_gap}s exceeded threshold ${RWX_FAST_FAILOVER_MAX_OUTAGE_SECONDS}s for pod ${pod_name}
        END
    END

    # The other active daemonset pods (on nodes that were not powered off)
    # should not run into errors during the failover.
    And Check daemonset 0 pods did not restart

    When Power on off nodes
    Then Wait for volume of daemonset 0 healthy

RWX Fast Failover With Multiple Simultaneous Deployments
    [Arguments]    ${nfs_options}
    [Documentation]    Verify RWX fast failover behavior when many RWX volumes are in use
    ...    simultaneously and only one worker node goes down.
    ...
    ...    Steps:
    ...    1. Enable rwx-volume-fast-failover feature.
    ...    2. Create 33 deployments with 3 replicas using a RWX volume each. They should
    ...       be evenly distributed across the worker nodes.
    ...    3. Power off one of the nodes. That should cause about 1/3 of the pods
    ...       (share-manager pods) to relocate.
    ...    4. All affected share-manager pods should be recreated and become running again.
    ...    5. Outage, including grace period, for all affected volumes should be less
    ...       than ${RWX_FAST_FAILOVER_MAX_OUTAGE_SECONDS} seconds.
    ...    6. RWX volumes not originally on the failed node should be unaffected.
    Given Setting rwx-volume-fast-failover is set to true
    And Create storageclass longhorn-test with
    ...    dataEngine=${DATA_ENGINE}
    ...    nfsOptions=${nfs_options}
    ...    numberOfReplicas=3

    FOR    ${i}    IN RANGE    33
        Create persistentvolumeclaim ${i}    volume_type=RWX    sc_name=longhorn-test
        Create deployment ${i} with persistentvolumeclaim ${i}
        ...    replicaset=3
        ...    args=exec 7<>/data/testfile-$(hostname -s); flock -x 7; while date +%s | dd conv=fsync >&7 ; do sleep 1; done;
    END

    FOR    ${i}    IN RANGE    33
        Wait for volume of deployment ${i} healthy
    END

    # Record which node each deployment's share manager is running on before the
    # outage, so we can later determine which deployments are actually affected
    # by the node outage, and verify pods are evenly distributed beforehand.
    &{node_deployment_count} =    Create Dictionary    ${NODE_0}    ${0}    ${NODE_1}    ${0}    ${NODE_2}    ${0}
    @{affected_deployment_ids} =    Create List
    @{unaffected_deployment_ids} =    Create List
    FOR    ${i}    IN RANGE    33
        ${volume_node} =    Get deployment ${i} volume node
        ${current_count} =    Get From Dictionary    ${node_deployment_count}    ${volume_node}
        ${current_count} =    Evaluate    ${current_count} + 1
        Set To Dictionary    ${node_deployment_count}    ${volume_node}=${current_count}
        IF    '${volume_node}' == '${NODE_0}'
            Append To List    ${affected_deployment_ids}    ${i}
        ELSE
            Append To List    ${unaffected_deployment_ids}    ${i}
        END
    END
    Log To Console    Share manager distribution before outage: ${node_deployment_count}

    # Verify share manager pods are roughly evenly distributed across the 3 worker nodes
    ${expected_per_node} =    Evaluate    33 / 3.0
    FOR    ${node_name}    ${count}    IN    &{node_deployment_count}
        Log To Console    Node ${node_name} has ${count} share manager pod(s)
        Should Be True    abs(${count} - ${expected_per_node}) <= ${expected_per_node}
        ...    Share manager pods are not evenly distributed: node ${node_name} has ${count}, expected around ${expected_per_node}
    END

    Power off node 0

    # Every affected deployment's share manager pod should be recreated on a
    # remaining node and become running again, with the outage duration verified
    # via the gap between consecutive epoch seconds appended to the testfile.
    FOR    ${i}    IN    @{affected_deployment_ids}
        Wait for sharemanager pod of deployment ${i} running

        ${pod_name} =    Get pod name of deployment ${i}
        ${content} =    Run command    kubectl exec ${pod_name} -- sh -c "cat /data/testfile-*"
        ${nums} =    Evaluate    [int(x) for x in $content.split()]
        ${max_gap} =    Evaluate    max([b - a for a, b in zip($nums, $nums[1:])]) if len($nums) > 1 else 0
        Should Be True    ${max_gap} <= ${RWX_FAST_FAILOVER_MAX_OUTAGE_SECONDS}
        ...    IO outage of ${max_gap}s exceeded threshold ${RWX_FAST_FAILOVER_MAX_OUTAGE_SECONDS}s for deployment ${i}
    END

    # RWX volumes not originally on the failed node should be unaffected
    FOR    ${i}    IN    @{unaffected_deployment_ids}
        Wait for volume of deployment ${i} healthy
        Check deployment ${i} pods did not restart
    END

    Power on off nodes

*** Test Cases ***

RWX Fast Failover IO Outage Duration With Soft NFS Mount Options
    [Tags]    rwx-fast-failover    node-down
    RWX Fast Failover IO Outage Duration    nfs_options=soft,timeo=250,retrans=5

RWX Fast Failover IO Outage Duration With NFSv4 Mount Options
    [Tags]    rwx-fast-failover    node-down
    RWX Fast Failover IO Outage Duration    nfs_options=vers=4.0,noresvport,softerr,timeo=600,retrans=5

RWX Fast Failover IO Outage Duration With Hard NFS Mount Options
    [Tags]    rwx-fast-failover    node-down
    RWX Fast Failover IO Outage Duration    nfs_options=hard,timeo=50,retrans=1

RWX Fast Failover With DaemonSet And Auto Delete Pod Disabled With Soft NFS Mount Options
    [Tags]    rwx-fast-failover    node-down    daemonset
    RWX Fast Failover With DaemonSet And Auto Delete Pod Disabled    nfs_options=soft,timeo=250,retrans=5

RWX Fast Failover With DaemonSet And Auto Delete Pod Disabled With NFSv4 Mount Options
    [Tags]    rwx-fast-failover    node-down    daemonset
    RWX Fast Failover With DaemonSet And Auto Delete Pod Disabled    nfs_options=vers=4.0,noresvport,softerr,timeo=600,retrans=5

RWX Fast Failover With DaemonSet And Auto Delete Pod Disabled With Hard NFS Mount Options
    [Tags]    rwx-fast-failover    node-down    daemonset
    RWX Fast Failover With DaemonSet And Auto Delete Pod Disabled    nfs_options=hard,timeo=50,retrans=1

RWX Fast Failover With Multiple Simultaneous Deployments With Soft NFS Mount Options
    [Tags]    rwx-fast-failover    node-down
    RWX Fast Failover With Multiple Simultaneous Deployments    nfs_options=soft,timeo=250,retrans=5

RWX Fast Failover With Multiple Simultaneous Deployments With NFSv4 Mount Options
    [Tags]    rwx-fast-failover    node-down
    RWX Fast Failover With Multiple Simultaneous Deployments    nfs_options=vers=4.0,noresvport,softerr,timeo=600,retrans=5

RWX Fast Failover With Multiple Simultaneous Deployments With Hard NFS Mount Options
    [Tags]    rwx-fast-failover    node-down
    RWX Fast Failover With Multiple Simultaneous Deployments    nfs_options=hard,timeo=50,retrans=1
