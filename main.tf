terraform {
  required_version = ">= 0.13.0"
  required_providers {
    aws = {
      version = "~> 3.28"
    }

    git = {
      source  = "innovationnorway/git"
      version = "~> 0.1.3"
    }
  }
  // backend "s3" {
  //   region = "us-west-2"
  // }
}

data "git_repository" "self" {
  path = path.module
}

# resource "aws_key_pair" "swipe_batch" {
#   key_name   = "${var.APP_NAME}-${var.DEPLOYMENT_ENVIRONMENT}"
#   public_key = var.BATCH_SSH_PUBLIC_KEY
# }

module "batch_queue" {
  source                   = "./terraform/modules/swipe-sfn-batch-queue"
  app_name                 = var.APP_NAME
  deployment_environment   = var.DEPLOYMENT_ENVIRONMENT
  # batch_ssh_key_pair_id    = aws_key_pair.swipe_batch.id
  batch_subnet_ids         = var.batch_subnet_ids
  batch_security_group_ids = var.batch_security_group_ids
  batch_ec2_instance_types = var.DEPLOYMENT_ENVIRONMENT == "test" ? ["optimal"] : ["r5d"]
}

module "sfn" {
  source                   = "./terraform/modules/swipe-sfn"
  app_name                 = var.APP_NAME
  deployment_environment   = var.DEPLOYMENT_ENVIRONMENT
  batch_job_docker_image   = "ghcr.io/chanzuckerberg/swipe:sha-${substr(data.git_repository.self.commit_sha, 0, 7)}"
  batch_spot_job_queue_arn = module.batch_queue.batch_spot_job_queue_arn
  batch_ec2_job_queue_arn  = module.batch_queue.batch_ec2_job_queue_arn
  additional_s3_path       = var.additional_s3_path
}

output "sfn_arn" {
  value = module.sfn.sfn_arn
}
