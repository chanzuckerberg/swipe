variable "app_name" {
  description = "App name (will appear in managed asset names)"
  type        = string
  default     = "swipe"
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "batch_ec2_instance_types" {
  description = "EC2 instance types to use for Batch EC2 compute environments"
  type        = list(string)
  default     = ["r5d.4xlarge"]
}

variable "batch_subnet_ids" {
  description = "EC2 subnet IDs for Batch EC2 compute environment container instances"
  type        = list(string)
  default     = []
}

variable "batch_ssh_key_pair_id" {
  description = "EC2 SSH key pair to use for Batch EC2 container instances"
  type        = string
  default     = ""
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
