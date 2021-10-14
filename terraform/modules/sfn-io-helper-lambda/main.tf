resource "aws_iam_role" "iam_role" {
  name = "${var.app_name}-${var.deployment_environment}-${var.name}"

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
  function_name    = "${var.app_name}-${var.deployment_environment}-${var.name}"
  runtime          = "python3.8"
  handler          = "app.${var.name}"
  memory_size      = 256
  timeout          = 600
  source_code_hash = filebase64sha256(var.zip)
  filename         = var.zip

  role = aws_iam_role.iam_role.arn
  tags = var.tags

  environment {
    variables = {
      DEPLOYMENT_ENVIRONMENT = var.deployment_environment
      RunSPOTMemoryDefault   = "128000"
      RunEC2MemoryDefault    = "128000"
      AWS_ENDPOINT_URL       = var.deployment_environment == "test" ? "http://host.docker.internal:9000" : ""
    }
  }
}
