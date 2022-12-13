// Passthrough from root module

variable "app_name" {
  type        = string
  description = "The name of your application, to be used as a namespace for all swipe managed assets"
}

variable "job_policy_arns" {
  description = "Policy ARNs to attach to batch jobs"
  type        = list(string)
}

variable "miniwdl_dir" {
  description = "Directory to mount from batch host into swipe jobs"
  type        = string
  default     = "/mnt"
}

variable "workspace_s3_prefixes" {
  description = "S3 prefixes where input, output, and log files will be stored, read and write permissions will be granted for this prefix"
  type        = list(string)
}

variable "wdl_workflow_s3_prefix" {
  description = "S3 prefix where WDL workflows are stored, read permissions will be granted for this prefix"
  type        = string
}

variable "extra_env_vars" {
  description = "Additional env vars to set on batch task definitions"
  type        = map(string)
}

variable "call_cache" {
  description = "If set to true swipe will cache WDL task results in S3 with the tag swipe_temporary='true' so they can be expired via a lifecycle policy"
  type        = bool
}

variable "output_status_json_files" {
  description = "If set to true, swipe will upload a JSON file with the status and possible description of each task during execution, useful for progress reporting"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
}

// Module Specific

variable "batch_job_docker_image" {
  description = "Docker image (name or name:tag) that will be used for AWS Batch Jobs running WDL workflows"
  type        = string
}

variable "batch_job_timeout_seconds" {
  description = "Timeout after which Batch will terminate jobs (Step Functions has a separate timeout for the SFN execution)"
  type        = number
}

variable "batch_job_retry_attempts" {
  description = "Number of times Batch will try to run the job. If using Step Functions, this is best left at 1 and retries configured in the SFN."
  type        = number
  default     = 1
}

variable "docker_network" {
  description = "If miniwdl's task containers should be attached to a specific docker network, set the network name here"
  type        = string
  default     = ""
}
