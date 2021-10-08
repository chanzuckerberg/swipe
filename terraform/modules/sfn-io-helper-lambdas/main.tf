module "preprocess" {
  source = "../sfn-io-helper-lambda"

  name    = "preprocess_input"
  zip     = filebase64sha256("${path.module}/deployment.zip")

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_default_region     = var.aws_default_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "preprocess" {
  source = "../sfn-io-helper-lambda"

  name    = "process_stage_output"
  zip     = filebase64sha256("${path.module}/deployment.zip")

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_default_region     = var.aws_default_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "handle_success" {
  source = "../sfn-io-helper-lambda"

  name    = "handle_success"
  zip     = filebase64sha256("${path.module}/deployment.zip")

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_default_region     = var.aws_default_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "handle_failure" {
  source = "../sfn-io-helper-lambda"

  name    = "handle_failure"
  zip     = filebase64sha256("${path.module}/deployment.zip")

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_default_region     = var.aws_default_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "process_batch_event" {
  source = "../sfn-io-helper-lambda"

  name    = "process_batch_event"
  zip     = filebase64sha256("${path.module}/deployment.zip")

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_default_region     = var.aws_default_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "process_sfn_event" {
  source = "../sfn-io-helper-lambda"

  name    = "process_sfn_event"
  zip     = filebase64sha256("${path.module}/deployment.zip")

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_default_region     = var.aws_default_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "report_metrics" {
  source = "../sfn-io-helper-lambda"

  name    = "report_metrics"
  zip     = filebase64sha256("${path.module}/deployment.zip")

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_default_region     = var.aws_default_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

module "report_spot_interruption" {
  source = "../sfn-io-helper-lambda"

  name    = "report_spot_interruption"
  zip     = filebase64sha256("${path.module}/deployment.zip")

  app_name               = var.app_name
  deployment_environment = var.deployment_environment
  aws_default_region     = var.aws_default_region
  aws_account_id         = var.aws_account_id
  tags                   = var.tags
}

resource "aws_cloudwatch_event_rule" "swipe-dev-process-batch-event-event" {
  name          = "swipe-dev-process-batch-event-event"
  tags          = var.tags

  event_pattern = jsonencode({
    "source" = ["aws.batch"],
    "detail" = {
      "status" = ["RUNNABLE"],
    },
  })
}

resource "aws_cloudwatch_event_rule" "swipe-dev-process-sfn-event-event" {
  name          = "swipe-dev-process-sfn-event-event"
  tags          = var.tags
  event_pattern = jsonencode({ "source" = ["aws.states"] })
}

resource "aws_cloudwatch_event_rule" "report_metrics-event" {
  name                = "report_metrics-event"
  schedule_expression = "rate(1 minute)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_rule" "report_spot_interruption-event" {
  name          = "report_spot_interruption-event"
  tags          = var.tags

  event_pattern = jsonencode({
    "source" = ["aws.ec2"],
    "detail" = {
      "type" = ["EC2 Spot Instance Interruption Warning"],
    },
  })
}

resource "aws_cloudwatch_event_target" "swipe-dev-process-batch-event-event" {
  rule      = aws_cloudwatch_event_rule.swipe-dev-process-batch-event-event.name
  target_id = "swipe-dev-process-batch-event-event"
  arn       = module.process_batch_event.lambda_arn
}

resource "aws_cloudwatch_event_target" "swipe-dev-process-sfn-event-event" {
  rule      = aws_cloudwatch_event_rule.swipe-dev-process-sfn-event-event.name
  target_id = "swipe-dev-process-sfn-event-event"
  arn       = module.process_sfn_event.lambda_arn
}

resource "aws_cloudwatch_event_target" "report_metrics-event" {
  rule      = aws_cloudwatch_event_rule.report_metrics-event.name
  target_id = "report_metrics-event"
  arn       = module.report_metrics.lambda_arn
}

resource "aws_cloudwatch_event_target" "report_spot_interruption-event" {
  rule      = aws_cloudwatch_event_rule.report_spot_interruption-event.name
  target_id = "report_spot_interruption-event"
  arn       = module.report_spot_interruption.lambda_arn
}

resource "aws_lambda_permission" "swipe-dev-process-batch-event-event" {
  function_name = module.process_batch_event.lambda_arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.swipe-dev-process-batch-event-event.arn
}

resource "aws_lambda_permission" "swipe-dev-process-sfn-event-event" {
  function_name = module.process_sfn_event.lamdba_arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.swipe-dev-process-sfn-event-event.arn
}

resource "aws_lambda_permission" "report_metrics-event" {
  function_name = module.report_metrics.lambda_arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.report_metrics-event.arn
}

resource "aws_lambda_permission" "report_spot_interruption-event" {
  function_name = module.report_spot_interruption.lambda_arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.report_spot_interruption-event.arn
}
