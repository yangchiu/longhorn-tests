*** Settings ***
Documentation       K8s keywords

Library             ../libs/keywords/k8s_keywords.py
Library             ../libs/keywords/workload_keywords.py
Library             ../libs/keywords/volume_keywords.py
Library             ../libs/keywords/node_keywords.py

*** Variables ***


*** Keywords ***
Stop volume node kubelet of statefulset ${idx} for ${stop_time_in_sec} seconds
    ${volume_name} =    get_workload_volume_name    ${statefulset_list}[${idx}]
    ${node_name} =    get_volume_node    ${volume_name}
    restart_kubelet    ${node_name}    ${stop_time_in_sec}

During replica rebuilding, delete volume node
    ${deleted_node} =    delete_volume_node    ${volume_name}
    Set Test Variable    ${deleted_node}

During replica rebuilding, delete replica node
    ${deleted_node} =    delete_replica_node    ${volume_name}
    Set Test Variable    ${deleted_node}

Add deleted node back
    reboot_node_by_name    ${deleted_node}