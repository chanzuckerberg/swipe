module "swipetest" {
  source                   = "../../.."
  call_cache               = true
  ami_ssm_parameter        = "/mock-aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
  miniwdl_dir              = "${path.cwd}/tmp"
  app_name                 = "swipe-test"
  batch_ec2_instance_types = ["optimal"]
  aws_endpoint_url         = "http://awsnet:4566"
  metrics_schedule         = "" # Localstack doesn't handle scheduled events well
  docker_network           = "awsnet"
  use_spot                 = false # Moto doesn't know how to use SPOT
  extra_env_vars = {
    "AWS_ACCESS_KEY_ID" : "role-account-id",
    "AWS_SECRET_ACCESS_KEY" : "role-secret-key",
    "AWS_SESSION_TOKEN" : "session-token",
    "AWS_ENDPOINT_URL" : "http://awsnet:4566",
    "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI" : "container-credentials-relative-uri",
    "S3PARCP_S3_URL" : "http://awsnet:4566",
  }
  sqs_queues = {
    "notifications" : { "dead_letter" : false }
  }
  sfn_template_files = {
    "stage-test" : "../../stage-test.yml"
  }
  stage_memory_defaults = {
    "Run" : { "spot" : 12800, "on_demand" : 256000 },
    "One" : { "spot" : 12800, "on_demand" : 256000 },
    "Two" : { "spot" : 12800, "on_demand" : 256000 },
  }
}
