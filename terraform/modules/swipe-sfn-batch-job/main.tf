data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  app_slug = "${var.app_name}-${var.deployment_environment}"
  ecr_url  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  container_config = yamldecode(templatefile("${path.module}/batch_job_container_properties.yml", {
    app_name           = var.app_name,
    batch_job_role_arn = aws_iam_role.swipe_batch_main_job.arn,
    batch_docker_image = var.batch_job_docker_image,
  }))
  batch_env_vars = merge(var.extra_env_vars, {
    "WDL_INPUT_URI"                             = "Set this variable to the S3 URI of the WDL input JSON",
    "WDL_WORKFLOW_URI"                          = "Set this variable to the S3 URI of the WDL workflow",
    "WDL_OUTPUT_URI"                            = "Set this variable to the S3 URI where the WDL output JSON will be written",
    "SFN_EXECUTION_ID"                          = "Set this variable to the current step function execution ARN",
    "SFN_CURRENT_STATE"                         = "Set this variable to the current step function state name, like HostFilterEC2 or HostFilterSPOT",
    "DEPLOYMENT_ENVIRONMENT"                    = var.deployment_environment,
    "AWS_DEFAULT_REGION"                        = data.aws_region.current.name,
    "MINIWDL__S3PARCP__DOCKER_IMAGE"            = var.batch_job_docker_image,
    "MINIWDL__DOWNLOAD_CACHE__PUT"              = "true",
    "MINIWDL__DOWNLOAD_CACHE__GET"              = "true",
    "MINIWDL__DOWNLOAD_CACHE__DIR"              = "/mnt/download_cache",
    "MINIWDL__DOWNLOAD_CACHE__DISABLE_PATTERNS" = "[\"s3://swipe-samples-*/*\"]",
    "DOWNLOAD_CACHE_MAX_GB"                     = "500",
    "WDL_PASSTHRU_ENVVARS"                      = join(" ", [for k, v in var.extra_env_vars : k]),
  })
  container_env_vars     = { "environment" : [for k, v in local.batch_env_vars : { "name" : k, "value" : v }] }
  final_container_config = merge(local.container_config, local.container_env_vars)
}

resource "aws_iam_policy" "swipe_batch_main_job" {
  name = "${local.app_slug}-batch-job"

  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: [
          "s3:List*",
          "s3:GetObject*",
          "s3:PutObject*",
          "s3:CreateMultipartUpload"
        ],
        Resource: compact([
          "arn:aws:s3:::aegea-batch-jobs-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::aegea-batch-jobs-${data.aws_caller_identity.current.account_id}/*",
          "arn:aws:s3:::sfn-wdl-dev",
          "arn:aws:s3:::sfn-wdl-dev/*",
          var.additional_s3_path != "" ? "arn:aws:s3:::${var.additional_s3_path}" : "", 
          var.additional_s3_path != "" ? "arn:aws:s3:::${var.additional_s3_path}/*" : "",
        ])
      },
      {
        Effect: "Allow",
        Action: [
          "s3:ListBucket",
        ],
        Resource: compact([
          "arn:aws:s3:::aegea-batch-jobs-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::sfn-wdl-dev",
          var.additional_s3_path != "" ? format("arn:aws:s3:::%s", split("/", var.additional_s3_path)[0]) : "", 
        ])
      },
      {
        Effect: "Allow",
        Action: [
          "cloudwatch:PutMetricData"
        ],
        Resource: "*"
      }
    ]
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

resource "aws_iam_role_policy_attachment" "swipe_batch_additional_policy" {
  role       = aws_iam_role.swipe_batch_main_job.name
  policy_arn = var.additional_policy_arn
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
  container_properties = jsonencode(local.final_container_config)
}
