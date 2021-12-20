variable "app_name" {
  type        = string
  description = "The name of your application, to be used as a namespace for all swipe managed assets"
}

variable "mock" {
  type        = bool
  default     = false
  description = "Set to true if applying to mock cloud environemnts for testing"
}

variable "batch_ssh_public_key" {
  type        = string
  default     = ""
  description = "Public SSH key for connecting to AWS Batch container instances. If none is provided swipe will generate one"
}

variable "network_info" {
  type = object({
    vpc_id           = string,
    batch_subnet_ids = list(string),
  })

  description = "VPC ID and subnet IDs within that VPC to use for AWS batch instances. If none is provided swipe will generate one"
  default     = null
}

variable "batch_ec2_instance_types" {
  type        = list(string)
  description = "EC2 instance types to use for AWS Batch compute environments"
  default     = ["r5d"]
}

variable "spot_min_vcpus" {
  type        = number
  description = "Minimum VCPUs for spot AWS Batch compute environment"
  default     = 8
}

variable "on_demand_min_vcpus" {
  type        = number
  description = "Minimum VCPUs for on demand AWS Batch compute environment"
  default     = 0
}

variable "spot_max_vcpus" {
  type        = number
  description = "Maximum VCPUs for spot AWS Batch compute environment"
  default     = 16
}

variable "on_demand_max_vcpus" {
  type        = number
  description = "Maximum VCPUs for on demand AWS Batch compute environment"
  default     = 16
}

variable "job_policy_arns" {
  type        = list(string)
  description = "Policy ARNs to attach to batch jobs"
  default     = []
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

variable "stage_vcpu_defaults" {
  type = map(object({
    on_demand = number,
    spot      = number,
  }))

  default = {
    "Run" : {
      on_demand = 2,
      spot      = 2,
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

