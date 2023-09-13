*** Settings ***
Documentation       Physical Node Keywords

Library             ../libs/keywords/volume_keywords.py
Library             ../libs/keywords/node_keywords.py
Library             ../libs/keywords/workload_keywords.py

*** Keywords ***
During replica rebuilding, reboot the volume attached node
    reboot_volume_attached_node    ${volume_name}

Reboot volume ${idx} attached node
    reboot_volume_attached_node    ${volume_list}[${idx}]
    FOR    ${item}    IN    @{volume_list}
        wait for volume_attached    ${item}
    END

During replica rebuilding, reboot the replica node
    reboot_node_with_replica    ${volume_name}

Reboot volume ${idx} replica node
    reboot_node_with_replica    ${volume_list}[${idx}]
    FOR    ${item}    IN    @{volume_list}
        wait for volume_attached    ${item}
    END

Restart cluster
    restart_all_nodes
    FOR    ${deployment}    IN    @{deployment_list}
        wait_for_workload_pod_stable   ${deployment}
    END
    FOR    ${statefulset}    IN    @{statefulset_list}
        wait_for_workload_pod_stable   ${statefulset}
    END
