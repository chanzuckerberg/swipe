module "preprocess" {
  source = "../sfn-io-helper-lambda"

  name = "preprocess_input"
  zip  = "${path.module}/deployment.zip"

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_region             = var.aws_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "process_stage_output" {
  source = "../sfn-io-helper-lambda"

  name = "process_stage_output"
  zip  = "${path.module}/deployment.zip"

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_region             = var.aws_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "handle_success" {
  source = "../sfn-io-helper-lambda"

  name = "handle_success"
  zip  = "${path.module}/deployment.zip"

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_region             = var.aws_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "handle_failure" {
  source = "../sfn-io-helper-lambda"

  name = "handle_failure"
  zip  = "${path.module}/deployment.zip"

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_region             = var.aws_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "process_batch_event" {
  source = "../sfn-io-helper-lambda"

  name = "process_batch_event"
  zip  = "${path.module}/deployment.zip"

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_region             = var.aws_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "process_sfn_event" {
  source = "../sfn-io-helper-lambda"

  name = "process_sfn_event"
  zip  = "${path.module}/deployment.zip"

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_region             = var.aws_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "report_metrics" {
  source = "../sfn-io-helper-lambda"

  name = "report_metrics"
  zip  = "${path.module}/deployment.zip"

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_region             = var.aws_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "report_spot_interruption" {
  source = "../sfn-io-helper-lambda"

  name = "report_spot_interruption"
  zip  = "${path.module}/deployment.zip"

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_region             = var.aws_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

resource "aws_cloudwatch_event_rule" "process_batch_event" {
  name = "${var.app_name}-${var.deployment_environment}-process_batch_event"
  tags = var.tags

  event_pattern = jsonencode({
    "source" = ["aws.batch"],
    "detail" = {
      "status"   = ["RUNNABLE"],
      "jobQueue" = var.batch_queue_arns,
    },
  })
}

resource "aws_cloudwatch_event_rule" "process_sfn_event" {
  name          = "${var.app_name}-${var.deployment_environment}-process_sfn_event"
  tags          = var.tags
  event_pattern = jsonencode({ "source" = ["aws.states"] })
}

resource "aws_cloudwatch_event_rule" "report_metrics" {
  name                = "report_metrics-event"
  schedule_expression = "rate(1 minute)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_rule" "report_spot_interruption" {
  name = "report_spot_interruption-event"
  tags = var.tags

  event_pattern = jsonencode({
    "source" = ["aws.ec2"],
    "detail" = {
      "type" = ["EC2 Spot Instance Interruption Warning"],
    },
  })
}

resource "aws_cloudwatch_event_target" "process_batch_event" {
  rule      = aws_cloudwatch_event_rule.process_batch_event.name
  target_id = "${var.app_name}-${var.deployment_environment}-process_batch_event"
  arn       = module.process_batch_event.lambda_arn
}

resource "aws_cloudwatch_event_target" "process_sfn_event" {
  rule      = aws_cloudwatch_event_rule.process_sfn_event.name
  target_id = "${var.app_name}-${var.deployment_environment}-process_batch_event"
  arn       = module.process_sfn_event.lambda_arn
}

resource "aws_cloudwatch_event_target" "report_metrics" {
  rule      = aws_cloudwatch_event_rule.report_metrics.name
  target_id = "report_metrics"
  arn       = module.report_metrics.lambda_arn
}

resource "aws_cloudwatch_event_target" "report_spot_interruption" {
  rule      = aws_cloudwatch_event_rule.report_spot_interruption.name
  target_id = "report_spot_interruption"
  arn       = module.report_spot_interruption.lambda_arn
}

resource "aws_lambda_permission" "process_batch_event" {
  function_name = module.process_batch_event.lambda_arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.process_batch_event.arn
}

resource "aws_lambda_permission" "process_sfn_event" {
  function_name = module.process_sfn_event.lambda_arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.process_sfn_event.arn
}

resource "aws_lambda_permission" "report_metrics" {
  function_name = module.report_metrics.lambda_arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.report_metrics.arn
}

resource "aws_lambda_permission" "report_spot_interruption" {
  function_name = module.report_spot_interruption.lambda_arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.report_spot_interruption.arn
}
