variable "app_name" {
  type = string
}

variable "mock" {
  type    = bool
  default = false
}

variable "batch_ssh_public_key" {
  type    = string
  default = ""
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "batch_subnet_ids" {
  description = "EC2 subnet IDs for Batch EC2 compute environment container instances"
  type        = list(string)
  default     = []
}

variable "job_policy_arns" {
  type        = list(string)
  description = "Policy ARNs to attach to batch jobs"
  default     = []
}

variable "batch_ec2_instance_types" {
  type        = list(string)
  description = "Instance type for Batch EC2 instances"
  default     = ["r5d"]
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

variable "additional_s3_path" {
  description = "additional S3 path to be granted permission for"
  type        = string
  default     = ""
}
