variable "APP_NAME" {
  type = string
}

variable "DEPLOYMENT_ENVIRONMENT" {
  type = string
}

variable "OWNER" {
  type = string
}

variable "batch_security_group_ids" {
  description = "EC2 security group IDs for Batch EC2 compute environment container instances"
  type        = list(string)
}

variable "batch_subnet_ids" {
  description = "EC2 subnet IDs for Batch EC2 compute environment container instances"
  type        = list(string)
}