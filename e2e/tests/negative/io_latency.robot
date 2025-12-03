*** Settings ***
Documentation    Negative Test Cases

Test Tags    io-latency    negative

Resource    ../keywords/variables.resource
Resource    ../keywords/common.resource
Resource    ../keywords/storageclass.resource
Resource    ../keywords/persistentvolumeclaim.resource
Resource    ../keywords/deployment.resource
Resource    ../keywords/statefulset.resource
Resource    ../keywords/workload.resource
Resource    ../keywords/io.resource

Test Setup    Set up test environment
Test Teardown    Cleanup test resources

*** Test Cases ***
Test Slow Disks
    Given Create storageclass longhorn-test with    dataEngine=v2
    And Create persistentvolumeclaim 0    sc_name=longhorn-test
    And Create deployment 0 with persistentvolumeclaim 0
    And Write 256 MB data to file data.bin in deployment 0

    When Inject IO latency
    Then Write 256 MB data to file data.bin in deployment 0

    When Cancel IO latency injection
    Then Write 256 MB data to file data.bin in deployment 0
