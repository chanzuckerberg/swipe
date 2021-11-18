variable "APP_NAME" {
  type = string
}

variable "DEPLOYMENT_ENVIRONMENT" {
  type = string
}

variable "BATCH_SSH_PUBLIC_KEY" {
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

variable "instance_type" {
  type        = list(string)
  description = "Instance type"
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

variable "ec2_desired_vcpus" {
  type        = number
  description = "Desired EC2 CPUs for this cluster"
  default     = 0
}