variable "app_name" {
  description = "App name (will appear in managed asset names)"
  type        = string
  default     = "swipe"
}

variable "extra_env_vars" {
  description = "Additional env vars to set on batch task definitions"
  type        = map(string)
  default     = {}
}

variable "batch_job_docker_image" {
  description = "Docker image (name or name:tag) that will be used for Batch jobs"
  type        = string
}

variable "batch_job_timeout_seconds" {
  description = "Timeout after which Batch will terminate jobs (Step Functions has a separate timeout for the SFN execution)"
  type        = number
  default     = 86400
}

variable "batch_job_retry_attempts" {
  description = "Number of times Batch will try to run the job. If using Step Functions, this is best left at 1 and retries configured in the SFN."
  type        = number
  default     = 1
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
  type = string
  default = ""
}

variable "additional_policy_arn" {
  type = string
  default = ""
}