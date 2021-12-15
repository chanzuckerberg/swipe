terraform {
  required_version = ">= 0.13.0"
  required_providers {
    aws = {
      version = "~> 3.28"
    }
  }
}

resource "aws_key_pair" "swipe_batch" {
  key_name   = var.app_name
  public_key = var.batch_ssh_public_key
  count      = var.batch_ssh_public_key != "" ? 1 : 0
}

module "batch_subnet" {
  source   = "./terraform/modules/swipe-sfn-batch-subnet"
  app_name = var.app_name
  count    = var.mock ? 1 : 0
}

module "batch_queue" {
  source                   = "./terraform/modules/swipe-sfn-batch-queue"
  app_name                 = var.app_name
  mock                     = var.mock
  vpc_id                   = var.vpc_id
  batch_ssh_key_pair_id    = length(aws_key_pair.swipe_batch) > 0 ? aws_key_pair.swipe_batch[0].id : ""
  batch_subnet_ids         = var.mock ? module.batch_subnet[0].batch_subnet_ids : var.batch_subnet_ids
  batch_ec2_instance_types = var.batch_ec2_instance_types
  min_vcpus                = var.min_vcpus
  max_vcpus                = var.max_vcpus
  spot_desired_vcpus       = var.spot_desired_vcpus
  on_demand_desired_vcpus  = var.on_demand_desired_vcpus
}

locals {
  version = file("${path.module}/version")
}

module "sfn" {
  source                   = "./terraform/modules/swipe-sfn"
  app_name                 = var.app_name
  batch_job_docker_image   = "ghcr.io/chanzuckerberg/swipe:${chomp(local.version)}"
  batch_spot_job_queue_arn = module.batch_queue.batch_spot_job_queue_arn
  batch_ec2_job_queue_arn  = module.batch_queue.batch_ec2_job_queue_arn
  workspace_s3_prefix      = var.workspace_s3_prefix
  wdl_workflow_s3_prefix   = var.wdl_workflow_s3_prefix
  job_policy_arns          = var.job_policy_arns
  sfn_template_files       = var.sfn_template_files
  stage_memory_defaults    = var.stage_memory_defaults
  extra_env_vars           = var.extra_env_vars
  tags                     = var.tags
}

output "sfn_arns" {
  value = module.sfn.sfn_arns
}
