data "archive_file" "lambda_archive" {
  type             = "zip"
  source_dir       = "${path.module}/app"
  output_file_mode = "0666"
  output_path      = "${path.module}/deployment.zip"
}

locals {
  lambda_names = toset([
    "preprocess_input",
    "process_stage_output",
    "handle_success",
    "handle_failure",
    "process_batch_event",
    "process_sfn_event",
    "report_metrics",
    "report_spot_interruption",
  ])
}

resource "aws_iam_role" "iam_role" {
  for_each = local.lambda_names


  name = "${var.app_name}-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action : "sts:AssumeRole",
        Effect : "Allow",
        Principal : {
          Service : "lambda.amazonaws.com",
        },
      },
    ],
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "iam_role_policy" {
  for_each = local.lambda_names

  name = each.key
  role = aws_iam_role.iam_role[each.key].id

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:List*",
          "s3:GetObject*",
          "s3:PutObject*"
        ],
        Resource : compact([
          "arn:aws:s3:::${var.app_name}-*",
          "arn:aws:s3:::${var.app_name}-*/*",
          "arn:aws:s3:::sfn-wdl-dev",
          "arn:aws:s3:::sfn-wdl-dev/*",
          var.additional_s3_path != "" ? "arn:aws:s3:::${var.additional_s3_path}" : "",
          var.additional_s3_path != "" ? "arn:aws:s3:::${var.additional_s3_path}/*" : "",
        ])
      },
      {
        Effect : "Allow",
        Action : [
          "batch:DescribeComputeEnvironments",
          "batch:DescribeJobDefinitions",
          "batch:DescribeJobQueues",
          "batch:DescribeJobs",
          "batch:ListJobs",
          "batch:TerminateJob",
          "batch:UpdateComputeEnvironment"
        ],
        Resource : "*"
      },
      {
        Effect : "Allow",
        Action : "states:ListStateMachines",
        Resource : "arn:aws:states:${var.aws_region}:${var.aws_account_id}:*"
      },
      {
        Effect : "Allow",
        Action : [
          "states:DescribeStateMachine",
          "states:ListExecutions",
          "states:DescribeExecution",
          "states:DescribeStateMachineForExecution",
          "states:GetExecutionHistory"
        ],
        Resource : [
          "arn:aws:states:${var.aws_region}:${var.aws_account_id}:stateMachine:${var.app_name}-*",
          "arn:aws:states:${var.aws_region}:${var.aws_account_id}:execution:${var.app_name}-*"
        ]
      },
      {
        Effect : "Allow",
        Action : "cloudwatch:PutMetricData",
        Resource : "*"
      },
      {
        Effect : "Allow",
        Action : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "lambda" {
  for_each = local.lambda_names

  function_name    = "${var.app_name}-${each.key}"
  runtime          = "python3.8"
  handler          = "app.${each.key}"
  memory_size      = 256
  timeout          = 600
  source_code_hash = data.archive_file.lambda_archive.output_sha
  filename         = data.archive_file.lambda_archive.output_path

  role = aws_iam_role.iam_role[each.key].arn
  tags = var.tags

  environment {
    variables = {
      APP_NAME             = var.app_name
      RunSPOTMemoryDefault = "16000"
      RunEC2MemoryDefault  = "16000"
      AWS_ENDPOINT_URL     = var.mock ? "http://host.docker.internal:9000" : null
    }
  }
}

resource "aws_cloudwatch_event_rule" "process_batch_event" {
  name = "${var.app_name}-process_batch_event"
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
  name          = "${var.app_name}-process_sfn_event"
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
  target_id = "${var.app_name}-process_batch_event"
  arn       = aws_lambda_function.lambda["process_batch_event"].arn
}

resource "aws_cloudwatch_event_target" "process_sfn_event" {
  rule      = aws_cloudwatch_event_rule.process_sfn_event.name
  target_id = "${var.app_name}-process_batch_event"
  arn       = aws_lambda_function.lambda["process_sfn_event"].arn
}

resource "aws_cloudwatch_event_target" "report_metrics" {
  rule      = aws_cloudwatch_event_rule.report_metrics.name
  target_id = "report_metrics"
  arn       = aws_lambda_function.lambda["report_metrics"].arn
}

resource "aws_cloudwatch_event_target" "report_spot_interruption" {
  rule      = aws_cloudwatch_event_rule.report_spot_interruption.name
  target_id = "report_spot_interruption"
  arn       = aws_lambda_function.lambda["report_spot_interruption"].arn
}

resource "aws_lambda_permission" "process_batch_event" {
  function_name = aws_lambda_function.lambda["process_batch_event"].arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.process_batch_event.arn
}

resource "aws_lambda_permission" "process_sfn_event" {
  function_name = aws_lambda_function.lambda["process_sfn_event"].arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.process_sfn_event.arn
}

resource "aws_lambda_permission" "report_metrics" {
  function_name = aws_lambda_function.lambda["report_metrics"].arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.report_metrics.arn
}

resource "aws_lambda_permission" "report_spot_interruption" {
  function_name = aws_lambda_function.lambda["report_spot_interruption"].arn
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.report_spot_interruption.arn
}
