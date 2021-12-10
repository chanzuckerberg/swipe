variable "app_name" {
  type = string
}

variable "mock" {
  type    = bool
  default = false
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "batch_queue_arns" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "workspace_s3_prefix" {
  type    = string
  default = ""
}

variable "stage_memory_defaults" {
  type = map(object({
    on_demand = number,
    spot      = number,
  }))
}

