terraform {
  required_version = ">= 0.13.0"
  required_providers {
    aws = {
      version = "~> 3.28"
    }
  }
}

resource "aws_key_pair" "swipe_batch" {
  key_name   = var.APP_NAME
  public_key = var.BATCH_SSH_PUBLIC_KEY
  count      = var.BATCH_SSH_PUBLIC_KEY != "" ? 1 : 0
}

module "batch_subnet" {
  source   = "./terraform/modules/swipe-sfn-batch-subnet"
  app_name = var.APP_NAME
  count    = var.vpc_id == "" || length(var.batch_subnet_ids) == 0 ? 1 : 0
}

module "batch_queue" {
  source                   = "./terraform/modules/swipe-sfn-batch-queue"
  app_name                 = var.APP_NAME
  batch_ssh_key_pair_id    = length(aws_key_pair.swipe_batch) > 0 ? aws_key_pair.swipe_batch[0].id : ""
  batch_subnet_ids         = length(module.batch_subnet) > 0 ? module.batch_subnet[0].batch_subnet_ids : var.batch_subnet_ids
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
  app_name                 = var.APP_NAME
  batch_job_docker_image   = "ghcr.io/chanzuckerberg/swipe:${local.version}"
  batch_spot_job_queue_arn = module.batch_queue.batch_spot_job_queue_arn
  batch_ec2_job_queue_arn  = module.batch_queue.batch_ec2_job_queue_arn
  additional_s3_path       = var.additional_s3_path
  job_policy_arns          = var.job_policy_arns
}

output "sfn_arn" {
  value = module.sfn.sfn_arn
}
