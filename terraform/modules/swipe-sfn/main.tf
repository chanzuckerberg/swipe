locals {
  sfn_template_files = merge(var.sfn_template_files, {
    "default" : "${path.module}/sfn-templates/single-wdl.yml",
  })
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "swipe_sfn_service" {
  name = "${var.app_name}-sfn-service"
  policy = templatefile("${path.module}/../../iam_policy_templates/sfn_service.json", {
    app_name              = var.app_name,
    sfn_service_role_name = "${var.app_name}-sfn-service",
    AWS_DEFAULT_REGION    = data.aws_region.current.name,
    AWS_ACCOUNT_ID        = data.aws_caller_identity.current.account_id,
  })
}

resource "aws_iam_role" "swipe_sfn_service" {
  name = "${var.app_name}-sfn-service"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["states"]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "swipe_sfn_service" {
  role       = aws_iam_role.swipe_sfn_service.name
  policy_arn = aws_iam_policy.swipe_sfn_service.arn
}

module "batch_job" {
  source                    = "../swipe-sfn-batch-job"
  app_name                  = var.app_name
  batch_job_docker_image    = var.batch_job_docker_image
  batch_job_timeout_seconds = var.batch_job_timeout_seconds
  workspace_s3_prefix       = var.workspace_s3_prefix
  job_policy_arns           = var.job_policy_arns
  extra_env_vars            = var.extra_env_vars
  tags                      = var.tags
}

module "sfn_io_helper" {
  source                = "../sfn-io-helper-lambdas"
  app_name              = var.app_name
  mock                  = var.mock
  aws_region            = data.aws_region.current.name
  aws_account_id        = data.aws_caller_identity.current.account_id
  batch_queue_arns      = [var.batch_spot_job_queue_arn, var.batch_ec2_job_queue_arn]
  workspace_s3_prefix   = var.workspace_s3_prefix
  stage_memory_defaults = var.stage_memory_defaults
  tags                  = var.tags
}

resource "aws_sfn_state_machine" "swipe_single_wdl" {
  for_each = merge(var.sfn_template_files, {
    "default" : "${path.module}/default-wdl.yml",
  })

  name     = "${var.app_name}-${each.key}-wdl"
  role_arn = aws_iam_role.swipe_sfn_service.arn
  definition = jsonencode(yamldecode(templatefile(each.value, {
    batch_spot_job_queue_arn         = var.batch_spot_job_queue_arn,
    batch_ec2_job_queue_arn          = var.batch_ec2_job_queue_arn,
    batch_job_definition_name        = module.batch_job.batch_job_definition_name,
    preprocess_input_lambda_name     = module.sfn_io_helper.preprocess_input_lambda_name,
    process_stage_output_lambda_name = module.sfn_io_helper.process_stage_output_lambda_name,
    handle_success_lambda_name       = module.sfn_io_helper.handle_success_lambda_name,
    handle_failure_lambda_name       = module.sfn_io_helper.handle_failure_lambda_name,
  })))
  tags = var.tags
}
