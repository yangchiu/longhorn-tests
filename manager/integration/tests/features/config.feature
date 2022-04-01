Feature: Config

  Scenario: Test AWS IAM Role ARN

    When set backup store to s3
    Then longhorn manager pods annotation should not have "iam.amazonaws.com/role"
    Then replica instance manager pods annotation should not have "iam.amazonaws.com/role"

    Then add key "AWS_IAM_ROLE_ARN" value "dGVzdC1hd3MtaWFtLXJvbGUtYXJu" to secret
    Then longhorn manager pods annotation should have key "iam.amazonaws.com/role" value "test-aws-iam-role-arn"
    Then replica instance manager pods annotation should have key "iam.amazonaws.com/role" value "test-aws-iam-role-arn"

    Then add key "AWS_IAM_ROLE_ARN" value "dGVzdC1hd3MtaWFtLXJvbGUtYXJuLTI=" to secret
    Then longhorn manager pods annotation should have key "iam.amazonaws.com/role" value "test-aws-iam-role-arn-2"
    Then replica instance manager pods annotation should have key "iam.amazonaws.com/role" value "test-aws-iam-role-arn-2"

    Then remove key "AWS_IAM_ROLE_ARN" from secret
    Then longhorn manager pods annotation should not have "iam.amazonaws.com/role"
    Then replica instance manager pods annotation should not have "iam.amazonaws.com/role"
