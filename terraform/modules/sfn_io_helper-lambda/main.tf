resource "aws_iam_role" "preprocess-input_role" {
  name = "swipe-dev-preprocess-input"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["lambda"],
  })
  tags = var.tags
}

resource "aws_iam_role" "process-stage-output_role" {
  name = "swipe-dev-process-stage-output"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["lambda"],
  })
  tags = var.tags
}

resource "aws_iam_role" "handle-success_role" {
  name = "swipe-dev-handle-success"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["lambda"],
  })
  tags = var.tags
}

resource "aws_iam_role" "handle-failure_role" {
  name = "swipe-dev-handle-failure"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["lambda"],
  })
  tags = var.tags
}

resource "aws_iam_role" "swipe-dev-process-batch-event_role" {
  name = "swipe-dev-swipe-dev-process-batch-event"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["lambda"],
  })
  tags = var.tags
}

resource "aws_iam_role" "swipe-dev-process-sfn-event_role" {
  name = "swipe-dev-swipe-dev-process-sfn-event"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["lambda"],
  })
  tags = var.tags
}

resource "aws_iam_role" "report_metrics_role" {
  name = "swipe-dev-report_metrics"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["lambda"],
  })
  tags = var.tags
}

resource "aws_iam_role" "report_spot_interruption_role" {
  name = "swipe-dev-report_spot_interruption"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["lambda"],
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "preprocess-input_role" {
  name = "preprocess-input_rolePolicy"
  policy = templatefile("${path.module}/../../iam_policy_templates/sfn-io-helper-lambda.json", {
    APP_NAME               = var.APP_NAME,
    DEPLOYMENT_ENVIRONMENT = var.DEPLOYMENT_ENVIRONMENT,
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
  role = aws_iam_role.preprocess-input_role.id
}

resource "aws_iam_role_policy" "process-stage-output_role" {
  name = "process-stage-output_rolePolicy"
  policy = templatefile("${path.module}/../../iam_policy_templates/sfn-io-helper-lambda.json", {
    APP_NAME               = var.APP_NAME,
    DEPLOYMENT_ENVIRONMENT = var.DEPLOYMENT_ENVIRONMENT,
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
  role = aws_iam_role.process-stage-output_role.id
}

resource "aws_iam_role_policy" "handle-success_role" {
  name = "handle-success_rolePolicy"
  policy = templatefile("${path.module}/../../iam_policy_templates/sfn-io-helper-lambda.json", {
    APP_NAME               = var.APP_NAME,
    DEPLOYMENT_ENVIRONMENT = var.DEPLOYMENT_ENVIRONMENT,
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
  role = aws_iam_role.handle-success_role.id
}

resource "aws_iam_role_policy" "handle-failure_role" {
  name = "handle-failure_rolePolicy"
  policy = templatefile("${path.module}/../../iam_policy_templates/sfn-io-helper-lambda.json", {
    APP_NAME               = var.APP_NAME,
    DEPLOYMENT_ENVIRONMENT = var.DEPLOYMENT_ENVIRONMENT,
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
  role = aws_iam_role.handle-failure_role.id
}

resource "aws_iam_role_policy" "swipe-dev-process-batch-event_role" {
  name = "swipe-dev-process-batch-event_rolePolicy"
  policy = templatefile("${path.module}/../../iam_policy_templates/sfn-io-helper-lambda.json", {
    APP_NAME               = var.APP_NAME,
    DEPLOYMENT_ENVIRONMENT = var.DEPLOYMENT_ENVIRONMENT,
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
  role = aws_iam_role.swipe-dev-process-batch-event_role.id
}

resource "aws_iam_role_policy" "swipe-dev-process-sfn-event_role" {
  name = "swipe-dev-process-sfn-event_rolePolicy"
  policy = templatefile("${path.module}/../../iam_policy_templates/sfn-io-helper-lambda.json", {
    APP_NAME               = var.APP_NAME,
    DEPLOYMENT_ENVIRONMENT = var.DEPLOYMENT_ENVIRONMENT,
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
  role = aws_iam_role.swipe-dev-process-sfn-event_role.id
}

resource "aws_iam_role_policy" "report_metrics_role" {
  name = "report_metrics_rolePolicy"
  policy = templatefile("${path.module}/../../iam_policy_templates/sfn-io-helper-lambda.json", {
    APP_NAME               = var.APP_NAME,
    DEPLOYMENT_ENVIRONMENT = var.DEPLOYMENT_ENVIRONMENT,
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
  role = aws_iam_role.report_metrics_role.id
}

resource "aws_iam_role_policy" "report_spot_interruption_role" {
  name = "report_spot_interruption_rolePolicy"
  policy = templatefile("${path.module}/../../iam_policy_templates/sfn-io-helper-lambda.json", {
    APP_NAME               = var.APP_NAME,
    DEPLOYMENT_ENVIRONMENT = var.DEPLOYMENT_ENVIRONMENT,
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
  role = aws_iam_role.report_spot_interruption_role.id
}

resource "aws_lambda_function" "preprocess-input" {
  function_name    = "swipe-dev-preprocess-input"
  runtime          = "python3.6"
  handler          = "app.preprocess_input"
  memory_size      = 256
  tags             = var.tags
  timeout          = 600
  source_code_hash = filebase64sha256("${path.module}/deployment.zip")
  filename         = "${path.module}/deployment.zip"

  environment {
    variables = {
      RunSPOTMemoryDefault = "128000"
      RunEC2MemoryDefault  = "128000"
    }
  }

  role = aws_iam_role.preprocess-input_role.arn
}

resource "aws_lambda_function" "process-stage-output" {
  function_name    = "swipe-dev-process-stage-output"
  runtime          = "python3.6"
  handler          = "app.process_stage_output"
  memory_size      = 256
  tags             = var.tags
  timeout          = 600
  source_code_hash = filebase64sha256("${path.module}/deployment.zip")
  filename         = "${path.module}/deployment.zip"

  environment {
    variables = {
      RunSPOTMemoryDefault = "128000"
      RunEC2MemoryDefault  = "128000"
    }
  }

  role = aws_iam_role.process-stage-output_role.arn
}

resource "aws_lambda_function" "handle-success" {
  function_name    = "swipe-dev-handle-success"
  runtime          = "python3.6"
  handler          = "app.handle_success"
  memory_size      = 256
  tags             = var.tags
  timeout          = 600
  source_code_hash = filebase64sha256("${path.module}/deployment.zip")
  filename         = "${path.module}/deployment.zip"

  environment {
    variables = {
      RunSPOTMemoryDefault = "128000"
      RunEC2MemoryDefault  = "128000"
    }
  }

  role = aws_iam_role.handle-success_role.arn
}

resource "aws_lambda_function" "handle-failure" {
  function_name    = "swipe-dev-handle-failure"
  runtime          = "python3.6"
  handler          = "app.handle_failure"
  memory_size      = 256
  tags             = var.tags
  timeout          = 600
  source_code_hash = filebase64sha256("${path.module}/deployment.zip")
  filename         = "${path.module}/deployment.zip"

  environment {
    variables = {
      RunSPOTMemoryDefault = "128000"
      RunEC2MemoryDefault  = "128000"
    }
  }

  role = aws_iam_role.handle-failure_role.arn
}

resource "aws_lambda_function" "swipe-dev-process-batch-event" {
  function_name    = "swipe-dev-swipe-dev-process-batch-event"
  runtime          = "python3.6"
  handler          = "app.process_batch_event"
  memory_size      = 256
  tags             = var.tags
  timeout          = 600
  source_code_hash = filebase64sha256("${path.module}/deployment.zip")
  filename         = "${path.module}/deployment.zip"

  environment {
    variables = {
      RunSPOTMemoryDefault = "128000"
      RunEC2MemoryDefault  = "128000"
    }
  }

  role = aws_iam_role.swipe-dev-process-batch-event_role.arn
}

resource "aws_lambda_function" "swipe-dev-process-sfn-event" {
  function_name    = "swipe-dev-swipe-dev-process-sfn-event"
  runtime          = "python3.6"
  handler          = "app.process_sfn_event"
  memory_size      = 256
  tags             = var.tags
  timeout          = 600
  source_code_hash = filebase64sha256("${path.module}/deployment.zip")
  filename         = "${path.module}/deployment.zip"

  environment {
    variables = {
      RunSPOTMemoryDefault = "128000"
      RunEC2MemoryDefault  = "128000"
    }
  }

  role = aws_iam_role.swipe-dev-process-sfn-event_role.arn
}

resource "aws_lambda_function" "report_metrics" {
  function_name    = "swipe-dev-report_metrics"
  runtime          = "python3.6"
  handler          = "app.report_metrics"
  memory_size      = 256
  tags             = var.tags
  timeout          = 600
  source_code_hash = filebase64sha256("${path.module}/deployment.zip")
  filename         = "${path.module}/deployment.zip"

  environment {
    variables = {
      RunSPOTMemoryDefault = "128000"
      RunEC2MemoryDefault  = "128000"
    }
  }

  role = aws_iam_role.report_metrics_role.arn
}

resource "aws_lambda_function" "report_spot_interruption" {
  function_name    = "swipe-dev-report_spot_interruption"
  runtime          = "python3.6"
  handler          = "app.report_spot_interruption"
  memory_size      = 256
  tags             = var.tags
  timeout          = 600
  source_code_hash = filebase64sha256("${path.module}/deployment.zip")
  filename         = "${path.module}/deployment.zip"

  environment {
    variables = {
      RunSPOTMemoryDefault = "128000"
      RunEC2MemoryDefault  = "128000"
    }
  }

  role = aws_iam_role.report_spot_interruption_role.arn
}

resource "aws_cloudwatch_event_rule" "swipe-dev-process-batch-event-event" {
  name          = "swipe-dev-process-batch-event-event"
  tags          = var.tags
  event_pattern = "{\"source\": [\"aws.batch\"], \"detail\": {\"status\": [\"RUNNABLE\"]}}"
}

resource "aws_cloudwatch_event_rule" "swipe-dev-process-sfn-event-event" {
  name          = "swipe-dev-process-sfn-event-event"
  tags          = var.tags
  event_pattern = "{\"source\": [\"aws.states\"]}"
}

resource "aws_cloudwatch_event_rule" "report_metrics-event" {
  name                = "report_metrics-event"
  schedule_expression = "rate(1 minute)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_rule" "report_spot_interruption-event" {
  name          = "report_spot_interruption-event"
  event_pattern = "{\"source\": [\"aws.ec2\"], \"detail\": {\"type\": [\"EC2 Spot Instance Interruption Warning\"]}}"
  tags          = var.tags
}

resource "aws_cloudwatch_event_target" "swipe-dev-process-batch-event-event" {
  rule      = aws_cloudwatch_event_rule.swipe-dev-process-batch-event-event.name
  target_id = "swipe-dev-process-batch-event-event"
  arn       = aws_lambda_function.swipe-dev-process-batch-event.arn
}

resource "aws_cloudwatch_event_target" "swipe-dev-process-sfn-event-event" {
  rule      = aws_cloudwatch_event_rule.swipe-dev-process-sfn-event-event.name
  target_id = "swipe-dev-process-sfn-event-event"
  arn       = aws_lambda_function.swipe-dev-process-sfn-event.arn
}

resource "aws_cloudwatch_event_target" "report_metrics-event" {
  rule      = aws_cloudwatch_event_rule.report_metrics-event.name
  target_id = "report_metrics-event"
  arn       = aws_lambda_function.report_metrics.arn
}

resource "aws_cloudwatch_event_target" "report_spot_interruption-event" {
  rule      = aws_cloudwatch_event_rule.report_spot_interruption-event.name
  target_id = "report_spot_interruption-event"
  arn       = aws_lambda_function.report_spot_interruption.arn
}

resource "aws_lambda_permission" "swipe-dev-process-batch-event-event" {
  function_name = aws_lambda_function.swipe-dev-process-batch-event.arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.swipe-dev-process-batch-event-event.arn
}

resource "aws_lambda_permission" "swipe-dev-process-sfn-event-event" {
  function_name = aws_lambda_function.swipe-dev-process-sfn-event.arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.swipe-dev-process-sfn-event-event.arn
}

resource "aws_lambda_permission" "report_metrics-event" {
  function_name = aws_lambda_function.report_metrics.arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.report_metrics-event.arn
}

resource "aws_lambda_permission" "report_spot_interruption-event" {
  function_name = aws_lambda_function.report_spot_interruption.arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.report_spot_interruption-event.arn
}
