// Passthrough from root module

variable "app_name" {
  type        = string
  description = "The name of your application, to be used as a namespace for all swipe managed assets"
}

variable "aws_endpoint_url" {
  type        = string
  description = "Override the AWS endpoint URL used by lambda functions"
}

variable "sfn_template_files" {
  description = "A map of names to YAML AWS Step Function State Machine Definition Templates. Useful for multi-stage workflows or custom compute environments, see documentation on multi-stage workflows for more information"
  type = map(object({
    path               = string
    exta_template_vars = map(string)
  }))
}

variable "job_policy_arns" {
  description = "Policy ARNs to attach to batch jobs"
  type        = list(string)
}


variable "workspace_s3_prefix" {
  description = "S3 prefix where input, output, and log files will be stored, read and write permissions will be granted for this prefix"
  type        = string
}

variable "wdl_workflow_s3_prefix" {
  description = "S3 prefix where WDL workflows are stored, read permissions will be granted for this prefix"
  type        = string
}

variable "stage_memory_defaults" {
  description = "The default memory requirements for each stage. To be used with multi-stage workflows, pass in requirements for Run for single-stage workflows"
  type = map(object({
    on_demand = number,
    spot      = number,
  }))
}

variable "stage_vcpu_defaults" {
  description = "The default vcpu requirements for each stage. To be used with multi-stage workflows, pass in requirements for Run for single-stage workflows"
  type = map(object({
    on_demand = number,
    spot      = number,
  }))
}

variable "extra_env_vars" {
  description = "Additional env vars to set on batch task definitions"
  type        = map(string)
}

variable "sqs_queues" {
  description = "A dictionary of sqs queue names to a map of options: visibility_timeout_seconds (default: '120'), dead_letter ('true'/'false' default: 'true')"
  type        = map(map(string))
}

variable "call_cache" {
  description = "If set to true swipe will cache WDL task results in S3 with the tag swipe_temporary='true' so they can be expired via a lifecycle policy"
  type        = bool
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
}

variable "docker_network" {
  description = "If miniwdl's task containers should be attached to a specific docker network, set the network name here"
  type        = string
}

// Module Specific

variable "batch_job_docker_image" {
  description = "Docker image (name or name:tag) that will be used for AWS Batch Jobs running WDL workflows"
  type        = string
}

variable "batch_job_timeout_seconds" {
  description = "Timeout after which Batch will terminate jobs (Step Functions has a separate timeout for the SFN execution)"
  type        = number
  default     = 86400
}

variable "batch_spot_job_queue_arn" {
  description = "ARN of the AWS Batch Queue connected to a spot compute environment created by this module"
  type        = string
}

variable "batch_on_demand_job_queue_arn" {
  description = "ARN of the AWS Batch Queue connected to an on demand compute environment created by this module"
  type        = string
}

variable "miniwdl_dir" {
  description = "Directory to mount from the batch host into the swipe container"
  type        = string
  default     = "/mnt"
}

variable "metrics_schedule" {
  description = "How often to report metrics, as a cloudwatch schedule expression"
  type        = string
  default     = "rate(1 minute)"
}
