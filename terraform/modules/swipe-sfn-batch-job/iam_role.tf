

locals {
  app_slug = "${var.app_name}-${var.deployment_environment}"
}

resource "aws_iam_policy" "swipe_batch_main_job" {
  name = "${local.app_slug}-batch-job"
  policy = templatefile("${path.module}/../../iam_policy_templates/batch_job.json", {
    S3_BUCKET_ARNS         = var.s3_bucket_arns
    AWS_DEFAULT_REGION     = data.aws_region.current.name,
    AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id,
  })
}

resource "aws_iam_role" "swipe_batch_main_job" {
  name = "${local.app_slug}-batch-job"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["ecs-tasks", "ec2"]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "swipe_batch_main_job" {
  role       = aws_iam_role.swipe_batch_main_job.name
  policy_arn = aws_iam_policy.swipe_batch_main_job.arn
}

resource "aws_iam_role_policy_attachment" "swipe_batch_main_job_ecr_readonly" {
  role       = aws_iam_role.swipe_batch_main_job.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
