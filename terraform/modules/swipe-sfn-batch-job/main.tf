locals {
  ecr_url  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_batch_job_definition" "swipe_main" {
  name = "${local.app_slug}-main"
  type = "container"
  tags = var.tags
  retry_strategy {
    attempts = var.batch_job_retry_attempts
  }
  timeout {
    attempt_duration_seconds = var.batch_job_timeout_seconds
  }
  container_properties = templatefile("${path.module}/batch_job_container_properties.json", {
    app_name               = var.namespace,
    deployment_environment = var.deployment_environment,
    batch_docker_image     = var.use_ecr_private_registry ? "${local.ecr_url}/${var.batch_job_docker_image_name}" : var.batch_job_docker_image_name,
    aws_region             = data.aws_region.current.name,
    batch_job_role_arn     = var.batch_role_arn
  })
}
