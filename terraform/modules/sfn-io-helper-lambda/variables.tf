variable "name" {
  type = string
}

variable "zip" {
  type = string
}

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

variable "tags" {
  type    = map(string)
  default = {}
}
