resource "aws_iam_policy" "swipe_sfn_service" {
  name = "swipe-${var.DEPLOYMENT_ENVIRONMENT}-sfn-service"
  policy = templatefile("${path.module}/iam_policy_templates/sfn_service.json", {
    sfn_service_role_name  = "swipe-${var.DEPLOYMENT_ENVIRONMENT}-sfn-service",
    AWS_DEFAULT_REGION     = var.AWS_DEFAULT_REGION,
    AWS_ACCOUNT_ID         = var.AWS_ACCOUNT_ID,
    DEPLOYMENT_ENVIRONMENT = var.DEPLOYMENT_ENVIRONMENT
  })
}

resource "aws_iam_role" "swipe_sfn_service" {
  name = "swipe-${var.DEPLOYMENT_ENVIRONMENT}-sfn-service"
  assume_role_policy = templatefile("${path.module}/iam_policy_templates/trust_policy.json", {
    trust_services = ["states"]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "swipe_sfn_service" {
  role       = aws_iam_role.swipe_sfn_service.name
  policy_arn = aws_iam_policy.swipe_sfn_service.arn
}

locals {
  sfn_common_params = {
    deployment_environment    = var.DEPLOYMENT_ENVIRONMENT,
    batch_spot_job_queue_name = aws_batch_job_queue.swipe_main["P10_SPOT"].name,
    batch_ec2_job_queue_name  = aws_batch_job_queue.swipe_main["P10_EC2"].name,
    batch_job_definition_name = aws_batch_job_definition.swipe_main.name,
  }
  sfn_common_tags = merge(local.common_tags, {
  })
}

resource "aws_sfn_state_machine" "swipe_single_wdl_1" {
  name     = "swipe-${var.DEPLOYMENT_ENVIRONMENT}-single-wdl-1"
  role_arn = aws_iam_role.swipe_sfn_service.arn
  definition = templatefile("${path.module}/sfn_templates/single-wdl-1.json", merge(local.sfn_common_params, {
    batch_job_name_prefix = "swipe-${var.DEPLOYMENT_ENVIRONMENT}-single-wdl",
  }))
  tags = local.sfn_common_tags
}
