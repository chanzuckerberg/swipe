provider "aws" {
  endpoints {
    stepfunctions    = "http://localhost:8083"
    batch            = "http://localhost:5000"
    iam              = "http://localhost:5000"
    ec2              = "http://localhost:5000"
    lambda           = "http://localhost:5000"
    cloudwatch       = "http://localhost:5000"
    cloudwatchevents = "http://localhost:5000"
    s3               = "http://localhost:5000"
    sts              = "http://localhost:5000"
    ssm              = "http://localhost:5000"
    secretsmanager   = "http://localhost:5000"
  }
}
