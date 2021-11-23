variable "app_name" {
  description = "App name (will appear in managed asset names)"
  type        = string
  default     = "swipe"
}

variable "mock" {
  type    = bool
  default = false
}


variable "vpc_id" {
  type    = string
  default = ""
}

variable "batch_ec2_instance_types" {
  description = "EC2 instance types to use for Batch EC2 compute environments"
  type        = list(string)
  default     = ["r5d"]
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

variable "min_vcpus" {
  type        = number
  description = "Minimum CPUs for this cluster"
  default     = 8
}

variable "max_vcpus" {
  type        = number
  description = "Maximum CPUs for this cluster"
  default     = 16
}

variable "spot_desired_vcpus" {
  type        = number
  description = "Desired Spot CPUs for this cluster"
  default     = 0
}

variable "on_demand_desired_vcpus" {
  type        = number
  description = "Desired on demand CPUs for this cluster"
  default     = 0
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
  default     = {}
}
