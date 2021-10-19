locals {
  app_slug          = "${var.app_name}-${var.deployment_environment}"
  sfn_template_file = var.sfn_template_file == "" ? "${path.module}/sfn-templates/single-wdl.yml" : var.sfn_template_file
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "swipe_sfn_service" {
  name = "${local.app_slug}-sfn-service"
  policy = templatefile("${path.module}/../../iam_policy_templates/sfn_service.json", {
    APP_NAME               = var.app_name,
    DEPLOYMENT_ENVIRONMENT = var.deployment_environment,
    sfn_service_role_name  = "${local.app_slug}-sfn-service",
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
}

resource "aws_iam_role" "swipe_sfn_service" {
  name = "${local.app_slug}-sfn-service"
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
  deployment_environment    = var.deployment_environment
  tags                      = var.tags
}

module "sfn_io_helper" {
  source                 = "../sfn-io-helper-lambdas"
  app_name               = var.app_name
  aws_region             = data.aws_region.current.name
  aws_account_id         = data.aws_caller_identity.current.account_id
  deployment_environment = var.deployment_environment
  batch_queue_arns       = [var.batch_spot_job_queue_arn, var.batch_ec2_job_queue_arn]
  tags                   = var.tags
}

resource "aws_sfn_state_machine" "swipe_single_wdl" {
  name     = "${local.app_slug}-single-wdl"
  role_arn = aws_iam_role.swipe_sfn_service.arn
  definition = jsonencode(yamldecode(templatefile(local.sfn_template_file, {
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
