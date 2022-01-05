provider "aws" {
  endpoints {
    batch            = "http://localhost:9000"
    cloudwatch       = "http://localhost:9000"
    cloudwatchevents = "http://localhost:9000"
    ec2              = "http://localhost:9000"
    iam              = "http://localhost:9000"
    lambda           = "http://localhost:9000"
    s3               = "http://localhost:9000"
    secretsmanager   = "http://localhost:9000"
    sns              = "http://localhost:9000"
    sqs              = "http://localhost:9000"
    ssm              = "http://localhost:9000"
    stepfunctions    = "http://localhost:8083"
    sts              = "http://localhost:9000"
  }
}
