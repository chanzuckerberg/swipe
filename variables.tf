variable "app_name" {
  description = "The name of your application, to be used as a namespace for all swipe managed assets"
  type        = string
}

variable "mock" {
  description = "Set to true if applying to mock cloud environemnts for testing"
  type        = bool
  default     = false
}

variable "batch_ssh_public_key" {
  description = "Public SSH key for connecting to AWS Batch container instances. If none is provided swipe will generate one"
  type        = string
  default     = ""
}

variable "network_info" {
  description = "VPC ID and subnet IDs within that VPC to use for AWS batch instances. If none is provided swipe will generate one"
  type = object({
    vpc_id           = string,
    batch_subnet_ids = list(string),
  })
  default = null
}

variable "batch_ec2_instance_types" {
  description = "EC2 instance types to use for AWS Batch compute environments"
  type        = list(string)
  default     = ["r5d"]
}

variable "spot_min_vcpus" {
  description = "Minimum VCPUs for spot AWS Batch compute environment"
  type        = number
  default     = 8
}

variable "on_demand_min_vcpus" {
  description = "Minimum VCPUs for on demand AWS Batch compute environment"
  type        = number
  default     = 0
}

variable "spot_max_vcpus" {
  description = "Maximum VCPUs for spot AWS Batch compute environment"
  type        = number
  default     = 16
}

variable "on_demand_max_vcpus" {
  description = "Maximum VCPUs for on demand AWS Batch compute environment"
  type        = number
  default     = 16
}

variable "sfn_template_files" {
  description = "A map of names to YAML AWS Step Function State Machine Definition Templates. To be used with multi-stage workflows, see documentation on multi-stage workflows for more information"
  type        = map(string)
  default     = {}
}

variable "job_policy_arns" {
  description = "Policy ARNs to attach to batch jobs"
  type        = list(string)
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

variable "stage_memory_defaults" {
  description = "The default memory requirements for each stage. To be used with multi-stage workflows, leave empty for single-stage workflows"
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
  description = "The default vcpu requirements for each stage. To be used with multi-stage workflows, leave empty for single-stage workflows"
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

