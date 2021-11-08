variable "APP_NAME" {
  type = string
}

variable "DEPLOYMENT_ENVIRONMENT" {
  type = string
}

variable "OWNER" {
  type = string
}

variable "BATCH_SSH_PUBLIC_KEY" {
  type    = string
  default = ""
}

variable "batch_security_group_ids" {
  description = "EC2 security group IDs for Batch EC2 compute environment container instances"
  type        = list(string)
  default     = []
}

variable "batch_subnet_ids" {
  description = "EC2 subnet IDs for Batch EC2 compute environment container instances"
  type        = list(string)
  default     = []
}

variable "additional_s3_path" {
  description = "additional S3 path to be granted permission for"
  type        = string
  default     = ""
}

variable "additional_policy_arn" {
  description = "Additional policy ARN for batch"
  type        = string
  default     = ""
}