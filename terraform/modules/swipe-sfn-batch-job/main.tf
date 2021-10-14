data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  app_slug = "${var.app_name}-${var.deployment_environment}"
  ecr_url  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

resource "aws_iam_policy" "swipe_batch_main_job" {
  name = "${local.app_slug}-batch-job"
  policy = templatefile("${path.module}/../../iam_policy_templates/batch_job.json", {
    APP_NAME               = var.app_name,
    DEPLOYMENT_ENVIRONMENT = var.deployment_environment,
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
}

resource "aws_iam_role" "swipe_batch_main_job" {
  name = "${local.app_slug}-batch-job"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["ecs-tasks"]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "swipe_batch_main_job" {
  role       = aws_iam_role.swipe_batch_main_job.name
  policy_arn = aws_iam_policy.swipe_batch_main_job.arn
}

resource "aws_iam_role_policy_attachment" "swipe_batch_main_job_ecr_readonly" {
  role       = aws_iam_role.swipe_batch_main_job.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

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
  container_properties = jsonencode(yamldecode(templatefile("${path.module}/batch_job_container_properties.yml", {
    app_name               = var.app_name,
    deployment_environment = var.deployment_environment,
    # TODO: fix docker image
    # batch_docker_image     = var.use_ecr_private_registry ? "${local.ecr_url}/${var.batch_job_docker_image_name}" : var.batch_job_docker_image_name,
    batch_docker_image = "ghcr.io/chanzuckerberg/swipe:sha-c145a0ab"
    aws_region         = data.aws_region.current.name,
    batch_job_role_arn = aws_iam_role.swipe_batch_main_job.arn,
  })))
}
