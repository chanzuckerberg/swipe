data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  region              = data.aws_region.current.name
  account_id          = data.aws_caller_identity.current.account_id
  job_definition_name = "${var.app_name}-main"
  ecr_url             = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com"
  hybrid_batch_queues = {
    # TODO: parameterize
    say_hello = "arn:aws:batch:${local.region}:${local.account_id}:job-queue/${var.app_name}-main-spot",
  }
  container_config = yamldecode(templatefile("${path.module}/batch_job_container_properties.yml", {
    miniwdl_dir        = var.miniwdl_dir,
    app_name           = var.app_name,
    batch_job_role_arn = aws_iam_role.swipe_batch_main_job.arn,
    batch_docker_image = var.batch_job_docker_image,
  }))
  cache_env_vars = var.call_cache ? {
    "MINIWDL__CALL_CACHE__PUT" : "true",
    "MINIWDL__CALL_CACHE__GET" : "true",
    "MINIWDL__CALL_CACHE__BACKEND" : "s3_progressive_upload_call_cache_backend",
  } : {}
  smart_batch_env_vars = {
    "MINIWDL__SCHEDULER__CONTAINER_BACKEND" : "hybrid_batch",
    "MINIWDL__S3_PROGRESSIVE_UPLOAD__BATCH_JOB_DEFINITION" : local.job_definition_name,
    "MINIWDL__S3_PROGRESSIVE_UPLOAD__BATCH_QUEUES" : jsonencode(local.hybrid_batch_queues),
  }
  batch_env_vars = merge(local.cache_env_vars, local.smart_batch_env_vars, var.extra_env_vars, {
    "WDL_INPUT_URI"                             = "Set this variable to the S3 URI of the WDL input JSON",
    "WDL_WORKFLOW_URI"                          = "Set this variable to the S3 URI of the WDL workflow",
    "WDL_OUTPUT_URI"                            = "Set this variable to the S3 URI where the WDL output JSON will be written",
    "SFN_EXECUTION_ID"                          = "Set this variable to the current step function execution ARN",
    "SFN_CURRENT_STATE"                         = "Set this variable to the current step function state name, like HostFilterEC2 or HostFilterSPOT",
    "APP_NAME"                                  = var.app_name
    "AWS_DEFAULT_REGION"                        = local.region,
    "MINIWDL_DIR"                               = var.miniwdl_dir
    "MINIWDL__TASK_RUNTIME__DEFAULTS"           = length(var.docker_network) > 0 ? jsonencode({ "docker_network" = var.docker_network }) : "{}"
    "MINIWDL__S3PARCP__DOCKER_IMAGE"            = var.batch_job_docker_image,
    "MINIWDL__S3PARCP__DIR"                     = var.miniwdl_dir
    "MINIWDL__DOCKER_SWARM__ALLOW_NETWORKS"     = length(var.docker_network) > 0 ? jsonencode([var.docker_network]) : "[]"
    "MINIWDL__DOWNLOAD_CACHE__PUT"              = "true",
    "MINIWDL__DOWNLOAD_CACHE__GET"              = "true",
    "MINIWDL__DOWNLOAD_CACHE__DIR"              = "${var.miniwdl_dir}/download_cache",
    "MINIWDL__DOWNLOAD_CACHE__DISABLE_PATTERNS" = "[\"s3://swipe-samples-*/*\"]",
    "DOWNLOAD_CACHE_MAX_GB"                     = "500",
    "WDL_PASSTHRU_ENVVARS"                      = join(" ", [for k, v in var.extra_env_vars : k]),
    "OUTPUT_STATUS_JSON_FILES"                  = tostring(var.output_status_json_files)
  })
  container_env_vars     = { "environment" : [for k in sort(keys(local.batch_env_vars)) : { "name" : k, "value" : local.batch_env_vars[k] }] }
  final_container_config = merge(local.container_config, local.container_env_vars)
}

data "aws_iam_policy_document" "swipe_batch_main_job" {
  statement {
    actions = [
      "batch:SubmitJob",
      "batch:DescribeJobs",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:batch:${local.region}:${local.account_id}:job-definition/${local.job_definition_name}",
    ]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:RequestTag/queue"
      values   = tolist(toset(values(local.hybrid_batch_queues)))
    }
  }

  statement {
    actions = [
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/batch/job:log-stream:${local.job_definition_name}/*",
    ]
  }

  statement {
    actions = [
      "s3:List*",
      "s3:GetObject*",
      "s3:PutObject*",
      "s3:DeleteObjectTagging",
      "s3:CreateMultipartUpload"
    ]
    effect = "Allow"
    resources = concat(
      compact([
        "arn:aws:s3:::aegea-batch-jobs-${local.account_id}",
        "arn:aws:s3:::aegea-batch-jobs-${local.account_id}/*",
        var.wdl_workflow_s3_prefix != "" ? "arn:aws:s3:::${var.wdl_workflow_s3_prefix}" : "",
        var.wdl_workflow_s3_prefix != "" ? "arn:aws:s3:::${var.wdl_workflow_s3_prefix}/*" : "",
      ]),
      [for workspace_s3_prefix in var.workspace_s3_prefixes : "arn:aws:s3:::${workspace_s3_prefix}"],
      [for workspace_s3_prefix in var.workspace_s3_prefixes : "arn:aws:s3:::${workspace_s3_prefix}/*"],
    )
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]
    effect = "Allow"
    resources = concat(
      compact([
        "arn:aws:s3:::aegea-batch-jobs-${local.account_id}",
        var.wdl_workflow_s3_prefix != "" ? format("arn:aws:s3:::%s", split("/", var.wdl_workflow_s3_prefix)[0]) : "",
      ]),
      [for workspace_s3_prefix in var.workspace_s3_prefixes : format("arn:aws:s3:::%s", split("/", workspace_s3_prefix)[0])],
    )
  }

  statement {
    actions = [
      "cloudwatch:PutMetricData"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

}

resource "aws_iam_policy" "swipe_batch_main_job" {
  name   = "${var.app_name}-batch-job"
  policy = data.aws_iam_policy_document.swipe_batch_main_job.json
}

resource "aws_iam_role" "swipe_batch_main_job" {
  name = "${var.app_name}-batch-job"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["ecs-tasks", "ec2"]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "swipe_batch_main_job" {
  role       = aws_iam_role.swipe_batch_main_job.name
  policy_arn = aws_iam_policy.swipe_batch_main_job.arn
}

resource "aws_iam_role_policy_attachment" "batch_job_policies" {
  count      = length(var.job_policy_arns)
  role       = aws_iam_role.swipe_batch_main_job.name
  policy_arn = var.job_policy_arns[count.index]
}

resource "aws_iam_role_policy_attachment" "swipe_batch_main_job_ecr_readonly" {
  role       = aws_iam_role.swipe_batch_main_job.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_batch_job_definition" "swipe_main" {
  name = "${var.app_name}-main"
  type = "container"
  tags = var.tags

  retry_strategy {
    attempts = var.batch_job_retry_attempts
  }

  timeout {
    attempt_duration_seconds = var.batch_job_timeout_seconds
  }

  container_properties = jsonencode(local.final_container_config)

  lifecycle {
    create_before_destroy = true
  }
}
