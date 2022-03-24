variable "app_name" {
  description = "The name of your application, to be used as a namespace for all swipe managed assets"
  type        = string
}

variable "use_spot" {
  description = "Whether to enable SPOT batch clusters - only disable this for testing!"
  type        = bool
  default     = true
}

variable "batch_ssh_public_key" {
  description = "Public SSH key for connecting to AWS Batch container instances. If none is provided swipe will generate one"
  type        = string
  default     = ""
}

variable "batch_ami_id" {
  description = "AMI ID to use (leave this empty to dynamically use the latest ECS optimized AMI)"
  type        = string
  default     = ""
}

variable "ami_ssm_parameter" {
  description = "The SSM parameter to use to fetch the AMI to use for batch jobs"
  type        = string
  default     = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

variable "miniwdl_dir" {
  description = "Directory to mount from the batch host into the swipe container"
  type        = string
  default     = "/mnt"
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

variable "aws_endpoint_url" {
  type        = string
  description = "Override the AWS endpoint URL used by lambda functions"
  default     = null
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

variable "sqs_queues" {
  description = "A dictionary of sqs queue names to a map of options: visibility_timeout_seconds (default: '120'), dead_letter ('true'/'false' default: 'true')"
  type        = map(map(string))
  default     = {}
}

variable "call_cache" {
  description = "If set to true swipe will cache WDL task results in S3 with the tag swipe_temporary='true' so they can be expired via a lifecycle policy"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
  default     = {}
}

variable "docker_network" {
  description = "If miniwdl's task containers should be attached to a specific docker network, set the network name here"
  type        = string
  default     = ""
}

variable "imdsv2_policy" {
  description = "Whether imdsv2 is 'optional' (default) or 'required'"
  type        = string
  default     = "optional"
}

variable "metrics_schedule" {
  description = "How often to report metrics, as a cloudwatch schedule expression"
  type        = string
  default     = "rate(1 minute)"
}
