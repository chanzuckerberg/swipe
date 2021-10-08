variable "app_name" {
  type = string
}

variable "deployment_environment" {
  type = string
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
  type = list(string)
}
