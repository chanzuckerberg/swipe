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
  tags     = var.tags
  count    = var.network_info == null ? 1 : 0
}

module "batch_queue" {
  source                = "./terraform/modules/swipe-sfn-batch-queue"
  app_name              = var.app_name
  batch_ssh_key_pair_id = length(aws_key_pair.swipe_batch) > 0 ? aws_key_pair.swipe_batch[0].id : ""
  network_info = length(module.batch_subnet) == 0 ? var.network_info : {
    vpc_id           = module.batch_subnet[0].vpc_id
    batch_subnet_ids = module.batch_subnet[0].batch_subnet_ids
  }
  ami_id                                  = var.batch_ami_id
  ami_ssm_parameter                       = var.ami_ssm_parameter
  miniwdl_dir                             = var.miniwdl_dir
  batch_ec2_instance_types                = var.batch_ec2_instance_types
  spot_min_vcpus                          = var.spot_min_vcpus
  on_demand_min_vcpus                     = var.on_demand_min_vcpus
  use_spot                                = var.use_spot
  spot_max_vcpus                          = var.spot_max_vcpus
  on_demand_max_vcpus                     = var.on_demand_max_vcpus
  tags                                    = var.tags
  imdsv2_policy                           = var.imdsv2_policy
  user_data_parts                         = var.user_data_parts
  compute_environment_allocation_strategy = var.compute_environment_allocation_strategy
}

locals {
  version = file("${path.module}/version")
}

module "sfn" {
  source                        = "./terraform/modules/swipe-sfn"
  app_name                      = var.app_name
  batch_job_docker_image        = "ghcr.io/chanzuckerberg/swipe:${chomp(local.version)}"
  batch_spot_job_queue_arn      = module.batch_queue.batch_spot_job_queue_arn
  batch_on_demand_job_queue_arn = module.batch_queue.batch_on_demand_job_queue_arn
  miniwdl_dir                   = var.miniwdl_dir
  docker_network                = var.docker_network
  workspace_s3_prefixes         = var.workspace_s3_prefixes
  aws_endpoint_url              = var.aws_endpoint_url
  wdl_workflow_s3_prefix        = var.wdl_workflow_s3_prefix
  job_policy_arns               = var.job_policy_arns
  metrics_schedule              = var.metrics_schedule
  sfn_template_files            = var.sfn_template_files
  stage_memory_defaults         = var.stage_memory_defaults
  stage_vcpu_defaults           = var.stage_vcpu_defaults
  extra_env_vars                = var.extra_env_vars
  sqs_queues                    = var.sqs_queues
  call_cache                    = var.call_cache
  tags                          = var.tags
}

output "sfn_arns" {
  value = module.sfn.sfn_arns
}

output "compute_environment_security_group_id" {
  description = "ID of the security group associated with the batch compute environments"
  value       = module.batch_queue.compute_environment_security_group_id
}

output "sfn_notification_queue_arns" {
  value = module.sfn.sfn_notification_queue_arns
}

output "sfn_notification_dead_letter_queue_arns" {
  value = module.sfn.sfn_notification_dead_letter_queue_arns
}
