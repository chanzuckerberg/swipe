provider "aws" {
  endpoints {
    stepfunctions    = "http://localhost:8083"
    batch            = "http://localhost:9000"
    iam              = "http://localhost:9000"
    ec2              = "http://localhost:9000"
    lambda           = "http://localhost:9000"
    cloudwatch       = "http://localhost:9000"
    cloudwatchevents = "http://localhost:9000"
    s3               = "http://localhost:9000"
    sts              = "http://localhost:9000"
    ssm              = "http://localhost:9000"
    secretsmanager   = "http://localhost:9000"
  }
}
