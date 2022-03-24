// Passthrough from root module
//
variable "app_name" {
  type        = string
  description = "The name of your application, to be used as a namespace for all swipe managed assets"
}

variable "aws_endpoint_url" {
  type        = string
  description = "Override the AWS endpoint URL used by lambda functions"
  default     = null
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

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
}

// Module Specific

variable "batch_queue_arns" {
  description = "ARNs of batch queues to be used for emitting batch job metrics"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS Region of your swipe AWS Batch state machines. To be used for permissions"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID of the account your swipe AWS Batch state machines are in. To be used for permissions"
  type        = string
}

variable "sfn_notification_queue_arns" {
  description = "ARNs of notification SQS queues"
  type        = list(string)
}

variable "schedule_expression" {
  description = "How frequently to report metrics (empty string disables scheduled metrics reporting)"
  type        = string
  default     = "rate(1 minute)"
}

variable "sfn_notification_queue_urls" {
  description = "URLs of notification SQS queues"
  type        = list(string)
}
