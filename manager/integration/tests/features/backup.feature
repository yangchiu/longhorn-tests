Feature: Backup

  Scenario: Test Backup Status For Unavailable Replica

    We want to make sure that during the backup creation, once the responsible
    replica gone, the backup should in Error state and with the error message.

    When set backup store to s3

    When create volume "volume-1" with size 512 MB
    Then attach volume "volume-1"

    Then write random data "data-1" to volume "volume-1" with size 512 MB
    Then create backup "backup-1" for volume "volume-1"

    Then find replica "replica-1" for backup "backup-1"
    Then find node "node-1" for replica "replica-1"
    Then disable node "node-1" scheduling

    Then delete replica "replica-1"
    Then backup "backup-1" should be in error state

    Then enable node "node-1" scheduling

    Then delete backup "backup-1"
    Then volume "volume-1" should have no backup

    Then create backup "backup-2" for volume "volume-1"
    Then wait for backup "backup-2" completed

    Then delete backup "backup-2"
    Then volume "volume-1" should have no backup