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

variable "workspace_s3_prefix" {
  description = "S3 prefix where input, output, and log files will be stored, read and write permissions will be granted for this prefix"
  type        = string
  default     = ""
}

variable "wdl_workflow_s3_prefix" {
  description = "S3 prefix where WDL workflows are stored, read permissions will be granted for this prefix"
  type        = string
  default     = ""
}

variable "sfn_template_files" {
  type    = map(string)
  default = {}
}

variable "stage_memory_defaults" {
  type = map({
    on_demand = number,
    spot      = number,
  })

  default = {
    "Run" : {
      on_demand = 128000,
      spot      = 128000,
    }
  }
}