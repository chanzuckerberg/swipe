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

variable "network_info" {
  type = map(object({
    vpc_id           = number,
    batch_subnet_ids = number,
  }))

  default = null
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
  type = map(object({
    on_demand = number,
    spot      = number,
  }))

  default = {
    "Run" : {
      on_demand = 128000,
      spot      = 128000,
    }
  }
}

variable "extra_env_vars" {
  description = "Additional env vars to set on batch task definitions"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
  default     = {}
}

