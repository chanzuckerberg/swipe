variable "app_name" {
  description = "App name (will appear in managed asset names)"
  type        = string
  default     = "swipe"
}

variable "sfn_template_file" {
  description = "JSON file with SFN contents (default: terraform/modules/swipe-sfn/sfn-templates/single-wdl-1.yml, transcoded to JSON)"
  type        = string
  default     = ""
}

variable "batch_job_docker_image" {
  description = "Docker image (name or name:tag) that will be used for Batch jobs (expected to be in the private registry for the host AWS account)"
  type        = string
}

variable "batch_job_timeout_seconds" {
  description = "Timeout after which Batch will terminate jobs (Step Functions has a separate timeout for the SFN execution)"
  type        = number
  default     = 86400
}

variable "batch_spot_job_queue_arn" {
  description = "ARN of the Batch spot EC2 job queue where this step function will submit its jobs"
  type        = string
}

variable "batch_ec2_job_queue_arn" {
  description = "ARN of the Batch ondemand EC2 job queue where this step function will submit its jobs"
  type        = string
}

variable "deployment_environment" {
  description = "deployment environment: (test, dev, staging, prod, etc.)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
  default     = {}
}

variable "additional_s3_path" {
  description = "additional S3 path to be granted permission for"
  type        = string
  default     = ""
}

variable "job_policy_arns" {
  type        = list(string)
  description = "Policy ARNs to attach to batch jobs"
  default     = []
}
