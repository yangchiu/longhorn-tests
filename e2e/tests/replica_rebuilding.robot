*** Settings ***
Documentation    Negative Test Cases

Test Tags    negative

Resource    ../keywords/common.resource
Resource    ../keywords/host.resource
Resource    ../keywords/volume.resource

Test Setup    Set test environment
Test Teardown    Cleanup test resources

*** Variables ***
${LOOP_COUNT}    1
${RETRY_COUNT}    300
${RETRY_INTERVAL}    1
${DATA_ENGINE}    v1

*** Test Cases ***
Delete Replica While Replica Rebuilding
    Given Create volume 0 with    size=2Gi    numberOfReplicas=3    dataEngine=${DATA_ENGINE}
    And Attach volume 0
    And Wait for volume 0 healthy
    And Write data to volume 0

    FOR    ${i}    IN RANGE    ${LOOP_COUNT}
        When Delete volume 0 replica on node 0
        And Wait until volume 0 replica rebuilding started on node 0
        And Delete volume 0 replica on node 1
        And Wait until volume 0 replica rebuilding completed on node 0
        And Delete volume 0 replica on node 2

        Then Wait until volume 0 replicas rebuilding completed
        And Wait for volume 0 healthy
        And Check volume 0 data is intact
    END

Reboot Volume Node While Replica Rebuilding
    Given Create volume 0 with    size=5Gi    numberOfReplicas=3    dataEngine=${DATA_ENGINE}
    And Attach volume 0
    And Wait for volume 0 healthy
    And Write data to volume 0

    FOR    ${i}    IN RANGE    ${LOOP_COUNT}
        When Delete volume 0 replica on volume node
        And Wait until volume 0 replica rebuilding started on volume node
        And Reboot volume 0 volume node

        Then Wait until volume 0 replica rebuilding completed on volume node
        And Wait for volume 0 healthy
        And Check volume 0 data is intact
    END

Reboot Replica Node While Replica Rebuilding
    Given Create volume 0 with    size=5Gi    numberOfReplicas=3    dataEngine=${DATA_ENGINE}
    And Attach volume 0
    And Wait for volume 0 healthy
    And Write data to volume 0

    FOR    ${i}    IN RANGE    ${LOOP_COUNT}
        When Delete volume 0 replica on replica node
        And Wait until volume 0 replica rebuilding started on replica node
        And Reboot volume 0 replica node

        Then Wait until volume 0 replica rebuilding completed on replica node
        And Wait for volume 0 healthy
        And Check volume 0 data is intact
    END
