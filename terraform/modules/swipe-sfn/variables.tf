variable "app_name" {
  description = "App name (will appear in managed asset names)"
  type        = string
  default     = "swipe"
}

variable "mock" {
  type    = bool
  default = false
}

variable "sfn_template_files" {
  type    = map(string)
  default = {}
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

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
  default     = {}
}

variable "workspace_s3_prefix" {
  description = "additional S3 path to be granted permission for"
  type        = string
  default     = ""
}

variable "wdl_workflow_s3_prefix" {
  description = "S3 prefix where WDL workflows are stored, read permissions will be granted for this prefix"
  type        = string
  default     = ""
}

variable "job_policy_arns" {
  type        = list(string)
  description = "Policy ARNs to attach to batch jobs"
  default     = []
}

variable "stage_memory_defaults" {
  type = map(object({
    on_demand = number,
    spot      = number,
  }))
}

variable "stage_vcpu_defaults" {
  type = map(object({
    on_demand = number,
    spot      = number,
  }))
}

variable "extra_env_vars" {
  description = "Additional env vars to set on batch task definitions"
  type        = map(string)
  default     = {}
}

