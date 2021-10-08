resource "aws_iam_role" "iam_role" {
  name = "swipe-${var.deployment_environment}-${var.name}"

  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["lambda"],
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "iam_role_policy" {
  name = var.name
  role = aws_iam_role.iam_role.id

  policy = templatefile("${path.module}/../../iam_policy_templates/sfn-io-helper-lambda.json", {
    app_name               = var.app_name,
    deployment_environment = var.deployment_environment,
    aws_region             = var.aws_region,
    aws_account_id         = var.aws_account_id,
  })
}

resource "aws_lambda_function" "lambda" {
  function_name    = "swipe-${var.deployment_environment}-${var.name}"
  runtime          = "python3.9"
  handler          = var.handler
  memory_size      = 256
  timeout          = 600
  source_code_hash = filebase64sha256(var.zip)
  filename         = var.zip

  environment {
    variables = {
      RunSPOTMemoryDefault = "128000"
      RunEC2MemoryDefault  = "128000"
    }
  }

  role = aws_iam_role.preprocess-input_role.arn
  tags = var.tags
}