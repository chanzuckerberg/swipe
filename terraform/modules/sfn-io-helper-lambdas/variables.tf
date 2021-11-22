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

variable "additional_s3_path" {
  type    = string
  default = ""
}
