provider "aws" {
  endpoints {
    stepfunctions    = "http://localhost:4566"
    batch            = "http://localhost:4566"
    iam              = "http://localhost:4566"
    ec2              = "http://localhost:4566"
    lambda           = "http://localhost:4566"
    cloudwatch       = "http://localhost:4566"
    cloudwatchevents = "http://localhost:4566"
    s3               = "http://localhost:4566"
    sts              = "http://localhost:4566"
    ssm              = "http://localhost:4566"
    secretsmanager   = "http://localhost:4566"
  }
}
