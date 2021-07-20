variable "namespace" {
  description = "Namespace prefix for swipe resources"
  type        = string
  default     = "swipe"
}

variable "batch_ec2_instance_types" {
  description = "EC2 instance types to use for Batch EC2 compute environments"
  type        = list(string)
  default     = ["r5d"]
}

variable "batch_security_group_ids" {
  description = "EC2 security group IDs for Batch EC2 compute environment container instances"
  type        = list(string)
}

variable "batch_subnet_ids" {
  description = "EC2 subnet IDs for Batch EC2 compute environment container instances"
  type        = list(string)
}

variable "batch_ssh_key_pair_id" {
  description = "EC2 SSH key pair to use for Batch EC2 container instances"
  type        = string
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
  default     = {}
}

variable "spot_desired_vcpus" {
  description = "Desired vcpus for spot fleet"
  type        = number
  default     = 16
}

variable "ec2_desired_vcpus" {
  description = "Desired vcpus for on-demand fleet"
  type        = number
  default     = 16
}

variable "min_vcpus" {
  description = "Min vcpus for batch fleet"
  type        = number
  default     = 0
}

variable "max_vcpus" {
  description = "Max vcpus for batch fleet"
  type        = number
  default     = 4096
}
